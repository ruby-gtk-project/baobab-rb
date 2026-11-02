# frozen_string_literal: true

require 'adwaita'

# Scanner walks a directory tree on a worker thread and reports the sizes back
# to the main thread.
#
# Ported from upstream's src/baobab-scanner.vala, including its Results inner
# class and ScanFlags enum. The structure is upstream's: the worker builds a
# Results object per directory and per file, groups each directory's children
# into one batch, and pushes the batches onto a queue; the main thread drains
# the queue from a timeout and links each batch into its parent's list store.
# Nothing but the main thread touches a list store, which is what keeps GTK's
# models consistent while a scan runs.
#
class Scanner
  # Upstream's ScanFlags, a GLib flags enum.
  NONE = 0
  EXCLUDE_MOUNTS = 1

  # Upstream's Scanner.State.
  SCANNING = :scanning
  ERROR = :error
  CHILD_ERROR = :child_error
  DONE = :done

  # Upstream's FileAttribute list, as the string GIO's enumerate_children and
  # query_info take.
  ATTRIBUTES = [
    'standard::name',
    'standard::display-name',
    'standard::type',
    'standard::size',
    'standard::allocated-size',
    'time::modified',
    'unix::nlink',
    'unix::inode',
    'unix::device',
  ].join(',').freeze

  # How often the main thread drains the worker's queue, in milliseconds.
  DRAIN_INTERVAL = 100

  # Results is one node of the scanned tree: a directory or a file.
  #
  # It is a GLib::Object because GTK's list models only hold GObjects. The four
  # fields the column sorters compare are installed as GObject properties as
  # well as Ruby attributes, because Gtk::StringSorter and Gtk::NumericSorter
  # read them through a Gtk::PropertyExpression; the Ruby bindings install a
  # property without generating accessors for it and then route the property
  # through the accessor of the same name, so both halves are needed. The rest
  # are plain attributes, which nothing outside Ruby reads.
  class Results < GLib::Object
    type_register

    READWRITE = GLib::Param::READABLE | GLib::Param::WRITABLE

    install_property(
      GLib::Param::String.new(
        'display-name',
        'display-name',
        'Name shown in the folder column',
        '',
        READWRITE,
      ),
    )
    install_property(
      GLib::Param::UInt64.new(
        'size',
        'size',
        'Bytes used by this node and its children',
        0,
        GLib::MAXUINT64,
        0,
        READWRITE,
      ),
    )
    install_property(
      GLib::Param::Int.new(
        'elements',
        'elements',
        'Files and folders counted under this node',
        0,
        GLib::MAXINT,
        0,
        READWRITE,
      ),
    )
    install_property(
      GLib::Param::UInt64.new(
        'time-modified',
        'time-modified',
        'Newest mtime in this subtree',
        0,
        GLib::MAXUINT64,
        0,
        READWRITE,
      ),
    )

    attr_accessor :parent,
      :name,
      :display_name,
      :file_type,
      :size,
      :time_modified,
      :elements,
      :max_depth,
      :error,
      :child_error,
      :state

    def initialize
      super
      @name = nil
      @display_name = ''
      @file_type = nil
      @size = 0
      @time_modified = 0
      @elements = 0
      @max_depth = 0
      @error = nil
      @child_error = false
      @state = SCANNING
      @percent = 0.0
    end

    # Upstream's Results (FileInfo, Results?) constructor.
    def self.for_file_info(info, parent)
      new.tap do |results|
        results.parent = parent
        results.name = info.name
        results.display_name = info.display_name || info.name.to_s
        results.file_type = info.file_type
        results.size = allocated_or_plain_size(info)
        results.time_modified = info.get_attribute_uint64('time::modified')
        results.elements = 1
      end
    end

    # Upstream uses the allocated size where the filesystem reports one, and
    # falls back to the apparent size where it reports zero.
    def self.allocated_or_plain_size(info)
      info.get_attribute_uint64('standard::allocated-size').then do |allocated|
        allocated.zero? ? info.size : allocated
      end
    end

    # Upstream's Results.empty (), used for the folder display's header row.
    def self.empty = new

    def children_list_store
      @children_list_store ||= Gio::ListStore.new(Results)
    end

    def percent = @percent

    def percent=(value)
      @percent = value.to_f
      value
    end

    def fraction = @percent / 100.0

    def empty? = children_list_store.n_items.zero?

    # Upstream's update_with_child, folding one child's totals into its parent.
    def update_with_child(child)
      @size += child.size
      @elements += child.elements
      @max_depth = [@max_depth, child.max_depth + 1].max
      @child_error ||= child.child_error || !child.error.nil?
      @time_modified = [@time_modified, child.time_modified].max
    end

    def depth
      ancestors.count + 1
    end

    def ancestors
      Enumerator.produce(parent) { |node| node.nil? ? raise(StopIteration) : node.parent }
                .take_while { |node| !node.nil? }
    end

    def ancestor_of?(descendant)
      Enumerator.produce(descendant) { |node| node.nil? ? raise(StopIteration) : node.parent }
                .take_while { |node| !node.nil? }
                .any? { |node| node.equal?(self) }
    end

    # Upstream's create_tree_model: a tree model over this node's children,
    # expanding lazily through each child's own list store. The sorter, when
    # one is given, sorts each level on its own — see TreeListRowSorter for why
    # the port sorts the levels rather than the flattened tree.
    def create_tree_model(sorter = nil)
      Gtk::TreeListModel.new(level_model(children_list_store, sorter), false, false) do |item|
        item.is_a?(Results) ? level_model(item.children_list_store, sorter) : nil
      end
    end

    def level_model(store, sorter)
      sorter.nil? ? store : Gtk::SortListModel.new(store, sorter)
    end

    # The state upstream's process_results assigns once a node's subtree is
    # known.
    def resolved_state
      case
      when child_error then CHILD_ERROR
      when !error.nil? then ERROR
      else DONE
      end
    end
  end

  attr_reader :directory, :scan_flags, :root, :total_size, :total_elements, :max_depth, :show_allocated_size

  def initialize(directory, flags = NONE, excluded_locations: [])
    @directory = directory
    @scan_flags = flags
    @excluded_locations = excluded_locations
    @queue = Queue.new
    @completed_callbacks = []
    @max_depth_callbacks = []
    reset_state
  end

  # Upstream models completion as a GObject signal; a plain callback list is
  # the same thing without registering a signal on a non-widget class.
  def on_completed(&block)
    @completed_callbacks << block
    block
  end

  def disconnect_completed(block)
    @completed_callbacks.delete(block)
  end

  # The charts bind themselves to upstream's max-depth property; here they
  # register for the same notification.
  def on_max_depth_changed(&block)
    @max_depth_callbacks << block
    block
  end

  def excluded_locations=(uris)
    @excluded_locations = uris
    uris
  end

  # Upstream's get_file: rebuild the file from the names on the path between
  # the scanned directory and this node.
  def get_file(results)
    path_names(results).inject(directory) { |file, name| file.get_child(name) }
  end

  # Upstream's scan (bool force).
  def scan(force = false)
    if force
      @successful = false
    end

    @successful ? notify_completed : start_scan
  end

  # Upstream's cancel ().
  def cancel
    unless @successful
      cancel_and_reset
      @scan_error = Cancelled.new('Scan was cancelled')
    end

    notify_completed
  end

  # Upstream's finish () throws the stored error; here it raises it, and the
  # window rescues Cancelled separately the way upstream catches IOError
  # CANCELLED.
  def finish
    unless @scan_error.nil?
      raise @scan_error
    end
  end

  def scanning? = !@thread.nil?

  # Raised in place of upstream's IOError.CANCELLED.
  class Cancelled < StandardError; end

  private

    def reset_state
      @root = nil
      @thread = nil
      @drain_id = nil
      @hardlinks = {}
      @unix_device = nil
      @scan_error = nil
      @successful = false
      @cancelled = false
      @total_size = 0
      @total_elements = 0
      @max_depth = 0
      @show_allocated_size = false
    end

    def path_names(results)
      results.ancestors
             .reverse
             .drop(1)
             .map(&:name)
             .then { |names| results.parent.nil? ? [] : names + [results.name] }
    end

    def start_scan
      cancel_and_reset

      @thread = Thread.new { scan_in_thread }
      @drain_id = GLib::Timeout.add(DRAIN_INTERVAL) { process_results }
    end

    def cancel_and_reset
      @cancelled = true

      unless @thread.nil?
        @thread.join
      end

      unless @drain_id.nil?
        GLib::Source.remove(@drain_id)
      end

      drain_queue
      reset_state
    end

    def drain_queue
      until @queue.empty?
        @queue.pop(true)
      end
    rescue ThreadError
      nil
    end

    # Upstream's scan_in_thread.
    def scan_in_thread
      info = directory.query_info(ATTRIBUTES, :none)
      @show_allocated_size = info.get_attribute_uint64('standard::allocated-size').positive?
      @unix_device = info.get_attribute_uint32('unix::device')

      add_directory(directory, info, nil).then do |results|
        unless results.nil?
          results.percent = 100.0
          @queue << [results]
        end
      end
    rescue StandardError, GLib::Error => e
      @queue << ScanFailure.new(e)
    ensure
      @queue << :finished
    end

    # Carries a worker-thread failure to the main thread. Upstream swallows the
    # error in scan_in_thread and lets the root's own error field report it;
    # the port keeps the exception so a failure to even open the root directory
    # still reaches the window.
    ScanFailure = Struct.new(:error)

    # Upstream's add_directory.
    def add_directory(dir, info, parent)
      case
      when excluded_mount?(info) then nil
      else scan_directory(dir, info, parent)
      end
    end

    def excluded_mount?(info)
      (scan_flags & EXCLUDE_MOUNTS).positive? &&
        info.get_attribute_uint32('unix::device') != @unix_device
    end

    def scan_directory(dir, info, parent)
      Results.for_file_info(info, parent).tap do |results|
        if excluded?(dir)
          results.error = ExcludedLocation.new('Location is excluded')
        else
          collect_directory(dir, results)
        end
      end
    end

    # Raised in place of upstream's IOError.FAILED ("Location is excluded").
    class ExcludedLocation < StandardError; end

    def collect_directory(dir, results)
      @total_size += results.size
      @total_elements += 1

      children = []

      begin
        add_children(dir, results, children)
      rescue StandardError, GLib::Error => e
        results.error = e
      end

      assign_percentages(results, children)
      @queue << children
    end

    def assign_percentages(results, children)
      children.each do |child|
        if results.size.positive?
          child.percent = 100.0 * child.size / results.size
        else
          child.percent = 0.0
        end
      end
    end

    # Upstream's add_children.
    def add_children(dir, results, children)
      enumerator = dir.enumerate_children(ATTRIBUTES, :nofollow_symlinks)

      while (child_info = next_child(enumerator))
        case child_info.file_type
        when Gio::FileType::DIRECTORY
          add_child_directory(
            dir,
            child_info,
            results,
            children,
          )
        when Gio::FileType::REGULAR
          add_child_file(child_info, results, children)
        end
      end

      enumerator.close
    end

    def next_child(enumerator)
      @cancelled ? nil : enumerator.next_file
    end

    def add_child_directory(dir, child_info, results, children)
      add_directory(dir.get_child(child_info.name), child_info, results).then do |child|
        unless child.nil?
          results.update_with_child(child)
          children << child
        end
      end
    end

    # Upstream counts a file with several hard links once, keyed on its inode
    # and device.
    def add_child_file(child_info, results, children)
      unless counted_hardlink?(child_info)
        Results.for_file_info(child_info, results).then do |child|
          @total_size += child.size
          @total_elements += 1
          results.update_with_child(child)
          children << child
        end
      end
    end

    def counted_hardlink?(info)
      case info.get_attribute_uint32('unix::nlink')
      when 0, 1 then false
      else seen_hardlink?(info)
      end
    end

    def seen_hardlink?(info)
      [info.get_attribute_uint64('unix::inode'), info.get_attribute_uint32('unix::device')]
        .then { |link| @hardlinks.key?(link) || remember_hardlink(link) }
    end

    # Returns false so the caller treats a first sighting as "not yet counted".
    def remember_hardlink(link)
      @hardlinks[link] = true
      false
    end

    def excluded?(dir) = @excluded_locations.include?(dir.uri)

    # Upstream's process_results, running on the main thread from a timeout.
    # Returns false once the root has been linked up, which removes the
    # timeout.
    def process_results
      batches = []

      until @queue.empty?
        batches << @queue.pop(true)
      end

      batches.map { |batch| handle_batch(batch) }.all?
    rescue ThreadError
      true
    end

    def handle_batch(batch)
      case batch
      when :finished then finish_thread
      when ScanFailure then fail_scan(batch.error)
      else link_batch(batch)
      end
    end

    def finish_thread
      @thread = nil
      @drain_id = nil
      false
    end

    def fail_scan(error)
      @scan_error = error
      @drain_id = nil
      @thread = nil
      notify_completed
      false
    end

    def link_batch(batch)
      batch.map { |results| link_results(results) }.all?
    end

    def link_results(results)
      unless results.parent.nil?
        results.parent.children_list_store.insert(0, results)
      end

      results.state = results.resolved_state
      update_max_depth(results.max_depth)

      results.parent.nil? ? complete_with_root(results) : true
    end

    def update_max_depth(depth)
      if depth > @max_depth
        @max_depth = depth
        @max_depth_callbacks.each { |callback| callback.call(@max_depth) }
      end
    end

    def complete_with_root(results)
      @root = results
      @scan_error = results.error
      @successful = true
      @drain_id = nil
      notify_completed
      false
    end

    def notify_completed
      @completed_callbacks.dup.each { |callback| callback.call(self) }
    end
end
