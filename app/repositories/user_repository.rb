class UserRepository
  class << self
    attr_reader :instance
  end

  def initialize
    @store = {}
    @last_id = 0
    @lock = Mutex.new
  end

  def all
    lock.synchronize { store.values.map { |user| User.new(user) } }
  end

  def create(attrs)
    user = User.new(writable(attrs))

    lock.synchronize do
      next unless user.valid?

      user.id = @last_id += 1
      store[user.id] = copy_attributes(user.attributes).freeze
    end

    user
  end

  def update(id, attrs)
    id = cast_id(id)

    lock.synchronize do
      stored_user = store[id]
      next unless stored_user

      user = User.new(stored_user)
      user.assign_attributes(writable(attrs))
      store[id] = copy_attributes(user.attributes).freeze if user.valid?

      user
    end
  end

  private

  attr_reader :store, :lock

  def cast_id(id)
    Integer(id.to_s, 10, exception: false)
  end

  def writable(attrs)
    attrs.to_h.symbolize_keys.slice(*User::WRITABLE_ATTRIBUTES)
  end

  def copy_attributes(attrs)
    attrs.transform_values { |value| value.duplicable? ? value.dup : value }
  end

  # Built when the class loads (at boot in production, via eager loading) so request threads can't race to create separate instances.
  @instance = new
end
