require "gibberish"
require "yaml"
require "secret_store/version"

class SecretStore
  attr_reader :file_path

  def initialize(password, file_path)
    self.password = password
    self.file_path = file_path
  end

  def store(key, secret, reload_data = true)
    load_data if reload_data

    if @data[key.to_s]
      raise "Key #{key} already stored"
    end

    insert_secret(key, secret)
    store_data
    load_data[key]
  end

  def store!(key, secret)
    load_data
    @data.delete(key.to_s)
    store(key, secret, false)
  end

  def get(key)
    if ciphertext = @data[key.to_s]
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
    store_data
  end

  private

  def file_path=(file_path)
    @file_path = file_path
    load_data
    @file_path
  end

  def password=(password)
    @cipher = nil
    @password = password
  end

  def cipher
    @cipher ||= Gibberish::AES.new(@password)
  end

  def load_data
    begin
      @data = YAML.load_file(file_path) || {}
    rescue Errno::ENOENT
      @data = {}
    end
  end

  def insert_secret(key, secret)
    @data.merge!(key.to_s => encrypt(secret))
  end

  def store_data
    File.open(@file_path, File::RDWR|File::CREAT|File::LOCK_EX, 0640) do |f|
      f.puts YAML.dump @data
    end
  end

  def decrypted_data
    @data.each_key.inject({}) do |decrypted_data, key|
      decrypted_data[key] = get(key)
      decrypted_data
    end
  end

  def replace_with_decrypted(decrypted)
    decrypted.each do |key, plaintext|
      @data[key] = encrypt(plaintext)
    end
  end
end
