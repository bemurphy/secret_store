require 'spec_helper'

describe SecretStore, "initializing" do
  let(:tmpfile) { Tempfile.new("secret_store") }

  it "takes a password and file path" do
    subject = SecretStore.new("pass", tmpfile.path)
  end

  it "can be optionally injected with a backend class" do
    klass = Class.new
    klass.should_receive(:new)
    subject = SecretStore.new("pass", tmpfile.path, :backend_class => klass)
  end
end

describe SecretStore, "storing a secret" do
  let(:tmpfile) { Tempfile.new("secret_store") }
  subject { SecretStore.new("the_pass", tmpfile.path) }

  context "when the key is not already stored" do
    it "stores the value for the key in a yaml data file" do
      subject.store("foobar", "fizzbuzz")
      data = YAML.load_file(tmpfile.path)
      data["foobar"].should_not be_empty
    end

    it "stores in an encrypted fashion" do
      subject.store("foobar", "fizzbuzz")
      data = YAML.load_file(tmpfile.path)
      data["foobar"].should_not == "fizzbuzz"
    end

    it "leaves other data in the store file intact" do
      tmpfile.puts YAML.dump("already" => "here")
      tmpfile.flush
      subject.store("foobar", "fizzbuzz")
      data = YAML.load_file(tmpfile.path)
      data["already"].should == "here"
    end
  end

  context "when the key is already stored" do
    it "raises" do
      subject.store("foobar", "fizzbuzz")
      lambda {
        subject.store("foobar", "fizzbuzz")
      }.should raise_error
    end

    it "can be overwritten with #store!" do
      subject.store("foobar", "fizzbuzz")
      subject.store!("foobar", "buzzfizz")
      subject.get("foobar").should == "buzzfizz"
    end
  end
end

describe SecretStore, "getting a secret" do
  let(:tmpfile) { Tempfile.new("secret_store") }
  subject { SecretStore.new("the_pass", tmpfile.path) }

  it "returns the decrypted secret" do
    subject.store("foobar", "fizzbuzz")
    subject.get("foobar").should == "fizzbuzz"
  end

  it "raises OpenSSL::Cipher::CipherError if the password for the store is wrong" do
    subject.store("foobar", "fizzbuzz")
    with_wrong_pass = SecretStore.new("wrong_pass", tmpfile.path)
    lambda {
      with_wrong_pass.get("foobar")
    }.should raise_error(OpenSSL::Cipher::CipherError)
  end

  context "when called via #get!" do
    it "raises IndexError if the key is not found" do
      lambda{
        subject.get!("not_found")
      }.should raise_error(IndexError)
    end
  end
end

describe SecretStore, "changing the password" do
  let(:tmpfile) { Tempfile.new("secret_store") }
  subject { SecretStore.new("the_pass", tmpfile.path) }

  it "resets the value for each secret key" do
    subject.store("foo", "bar")
    subject.store("fizz", "buzz")
    original_data = YAML.load_file(tmpfile.path)

    subject.change_password("new_password")

    data = YAML.load_file(tmpfile.path)
    data["foo"].should_not == original_data["foo"]
    data["fizz"].should_not == original_data["fizz"]
  end

  it "leaves you with the ability to get secrets using the new password" do
    subject.store("foo", "bar")
    subject.change_password("new_pass")

    subject.get("foo").should == "bar"

    with_new_pass = SecretStore.new("new_pass", tmpfile.path)
    subject.get("foo").should == "bar"
  end
end

describe SecretStore::YamlBackend do
  let(:tmpfile) { Tempfile.new("secret_store") }
  subject { SecretStore::YamlBackend.new(tmpfile.path) }

  before do
    tmpfile.puts YAML.dump("foo" => "bar", "fizz" => "buzz")
    tmpfile.flush
  end

  it "reads indifferently from its data using []" do
    subject["foo"].should == "bar"
    subject["fizz"].should == "buzz"
    subject[:fizz].should == "buzz"
  end

  it "can return the keys on data" do
    subject.keys.should =~ %w[foo fizz]
  end

  it "can reload data on demand" do
    File.open(tmpfile.path, 'w') do |f|
      f.puts YAML.dump("foo" => "reloaded")
    end

    subject.reload
    subject["foo"].should == "reloaded"
  end

  it "can insert a value for a non-existant key" do
    subject.insert("new", "value")
    subject.reload
    subject["new"].should == "value"
  end

  it "will raise an error trying to insert for an existing key" do
    lambda {
      subject.insert("foo", "123")
    }.should raise_error
  end

  it "can overwrite an existing key" do
    subject.overwrite("foo", "123")
    subject.reload
    subject["foo"].should == "123"
  end

  it "can delete a key" do
    subject.delete("foo").should == "bar"
    subject.reload
    subject.keys.should == ["fizz"]
  end

  it "can save the data" do
    subject.overwrite("foo", "123")
    data = SecretStore::YamlBackend.new(tmpfile.path)
    data["foo"].should == "123"
  end

  it "will auto reload the data if the file mtime changes" do
    subject["foo"].should == "bar"
    SecretStore::YamlBackend.new(tmpfile.path).overwrite("foo", "changed")
    FileUtils.touch(tmpfile.path, :mtime => Time.now + 5)
    subject["foo"].should == "changed"
  end

  it "can create a file that doesn't exist" do
    path = tmpfile.path
    tmpfile.unlink
    store = SecretStore::YamlBackend.new(path)
    store["foo"].should be_nil
    store.insert("foo", "bar")
    store["foo"].should == "bar"
  end
end

describe SecretStore::ReadOnlyYamlBackend do
  let(:tmpfile) { Tempfile.new("secret_store") }
  subject { SecretStore::ReadOnlyYamlBackend.new(tmpfile) }

  it "doesn't allow inserts" do
    lambda {
      subject.insert("foo", "bar")
    }.should raise_error(SecretStore::ReadOnly)
  end

  it "doesn't allow overwrites" do
    lambda {
      subject.overwrite("foo", "bar")
    }.should raise_error(SecretStore::ReadOnly)
  end

  it "doesn't allow deletes" do
    lambda {
      subject.delete("foo")
    }.should raise_error(SecretStore::ReadOnly)
  end
end
