require "gibberish"
require "yaml"
require "secret_store/version"

class SecretStore
  attr_reader :file_path

  def initialize(password, file_path)
    self.password = password
    self.file_path = file_path
  end

  def store(key, secret, force = false)
    load_data

    if ! force && @data[key.to_s]
      raise "Key #{key} already stored"
    end

    @data.merge!(key.to_s => encrypt(secret))
    store_data
    load_data[key]
  end

  def get(key)
    ciphertext = @data.fetch(key.to_s)
    cipher.decrypt(ciphertext)
  end

  def encrypt(secret)
    cipher.encrypt(secret).chomp
  end

  def change_password(new_password)
    new_data = {}

    @data.each_key do |key|
      new_data[key] = get(key)
    end

    self.password = new_password

    new_data.each do |key, plaintext|
      @data[key] = encrypt(plaintext)
    end

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

  def store_data
    File.open(@file_path, File::RDWR|File::CREAT|File::LOCK_EX, 0640) do |f|
      f.puts YAML.dump @data
    end
  end
end