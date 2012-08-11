require "gibberish"
require "yaml"
require "secret_store/version"

class SecretStore
  def initialize(password, file_path)
    self.password = password
    @data = YamlBackend.new(file_path)
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
    SAVE_FLAGS = File::RDWR | File::CREAT | File::LOCK_EX
    SAVE_PERMS = 0640

    def initialize(file_path)
      @file_path = file_path
    end

    def [](key)
      data[key.to_s]
    end

    def keys
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

    private

    def delete!(key)
      data.delete(key.to_s)
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
        f.truncate(0)
        f.puts YAML.dump(data)
      end
      true
    end
  end
end
