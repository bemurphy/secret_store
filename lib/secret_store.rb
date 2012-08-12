require "yaml"
require "gibberish"
require "secret_store/version"

class SecretStore
  class ReadOnly < RuntimeError; end

  def initialize(password, file_path, options = {})
    self.password = password
    backend_class = options.fetch(:backend_class, YamlBackend)
    @data = backend_class.new(file_path)
  end

  def self.new_read_only(password, file_path)
    new(password, file_path, :backend_class => ReadOnlyYamlBackend)
  end

  def store(key, secret)
    @data.insert(key, encrypt(secret))
  end

  def store!(key, secret)
    @data.overwrite(key, encrypt(secret))
  end

  def get(key)
    if ciphertext = @data[key]
      cipher.decrypt(ciphertext)
    end
  end

  def get!(key)
    get(key) or raise IndexError.new(%Q[key not found: "#{key}"])
  end

  def encrypt(secret)
    cipher.encrypt(secret).chomp
  end

  def change_password(new_password)
    unless @data.permits_writes?
      raise ReadOnly
    end

    decrypted = decrypted_data
    self.password = new_password
    replace_with_decrypted(decrypted)
  end

  private

  def password=(password)
    @cipher = nil
    @password = password
  end

  def cipher
    @cipher ||= Gibberish::AES.new(@password)
  end

  def decrypted_data
    @data.keys.inject({}) do |decrypted_data, key|
      decrypted_data[key] = get(key)
      decrypted_data
    end
  end

  def replace_with_decrypted(decrypted)
    decrypted.each do |key, plaintext|
      @data.overwrite(key, encrypt(plaintext))
    end
  end

  class YamlBackend
    SAVE_FLAGS = File::TRUNC | File::CREAT | File::LOCK_EX | File::LOCK_NB
    SAVE_PERMS = 0640

    def initialize(file_path)
      @file_path = file_path
    end

    def [](key)
      reload_if_updated
      data[key.to_s]
    end

    def keys
      reload_if_updated
      data.keys
    end

    def insert(key, value)
      if self[key]
        raise "Key #{key} already stored"
      end

      data[key.to_s] = value
      save
      value
    end

    def overwrite(key, value)
      delete!(key.to_s)
      insert(key, value)
    end

    def delete(key)
      return unless self[key]
      value = delete!(key)
      save && value
    end

    def reload
      @data = nil
      data && true
    end

    def permits_writes?
      true
    end

    private

    def delete!(key)
      reset_mtime_tracker
      data.delete(key.to_s)
    end

    def reload_if_updated
      mtime = File.exists?(@file_path) && File.mtime(@file_path)
      @mtime_tracker ||= mtime
      @mtime_tracker != mtime && reload
    end

    def data
      begin
        @data ||= YAML.load_file(@file_path) || {}
      rescue Errno::ENOENT
        @data = {}
      end
    end

    def save
      File.open(@file_path, SAVE_FLAGS, SAVE_PERMS) do |f|
        f.write YAML.dump(data)
        reset_mtime_tracker
        true
      end
    end

    def reset_mtime_tracker
      @mtime_tracker = nil
    end
  end

  class ReadOnlyYamlBackend < YamlBackend
    [:insert, :overwrite, :delete, :save].each do |meth|
      define_method meth do |*|
        raise ReadOnly
      end
    end

    def permits_writes?
      false
    end

    private

    def reload_if_updated
      #no-op
    end
  end
end
