require 'spec_helper'

describe SecretStore, "initializing" do
  let(:tmpfile) { Tempfile.new("secret_store") }

  it "takes a password and file path" do
    subject = SecretStore.new("pass", tmpfile.path)
    subject.file_path.should == tmpfile.path
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
    it "raises if not forced" do
      subject.store("foobar", "fizzbuzz")
      lambda {
        subject.store("foobar", "fizzbuzz")
      }.should raise_error
    end

    it "stores if forced" do
      subject.store("foobar", "fizzbuzz")
      lambda {
        subject.store("foobar", "fizzbuzz", :force)
      }.should_not raise_error
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

  it "raises IndexError if the key is not found" do
    lambda{
      subject.get("not_found")
    }.should raise_error(IndexError)
  end

  it "raises OpenSSL::Cipher::CipherError if the password for the store is wrong" do
    subject.store("foobar", "fizzbuzz")
    with_wrong_pass = SecretStore.new("wrong_pass", tmpfile.path)
    lambda {
      with_wrong_pass.get("foobar")
    }.should raise_error(OpenSSL::Cipher::CipherError)
  end
end

describe SecretStore, "changing the password" do
  let(:tmpfile) { Tempfile.new("secret_store") }
  subject { SecretStore.new("the_pass", tmpfile.path) }

  it "resets the value for each secret key" do
    tmpfile.puts YAML.dump("foo" => "bar", "fizz" => "buzz")
    subject.change_password("new_password")
    data = YAML.load_file(tmpfile.path)
    data["foo"].should_not == "bar"
    data["fizz"].should_not == "buzz"
  end

  it "leaves you with the ability to get secrets using the new password" do
    subject.store("foo", "bar")
    subject.change_password("new_pass")

    subject.get("foo").should == "bar"

    with_new_pass = SecretStore.new("new_pass", tmpfile.path)
    subject.get("foo").should == "bar"
  end
end
