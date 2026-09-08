require "rails_helper"

RSpec.describe Utils::Callable do
  it "delegates SomeClass.call(arg, kwarg: value, &block) to SomeClass.new(arg, kwarg: value, &block).call" do
    initialized_with = nil
    dummy_class = Class.new do
      include Utils::Callable

      define_method :initialize do |*args, **kwargs, &block|
        initialized_with = [ args, kwargs, block ]
      end

      def call
        "method result"
      end
    end

    expect(dummy_class.call("arg", kwarg: "value") { "block result" }).to eq("method result")
    expect(initialized_with[0]).to eq([ "arg" ])
    expect(initialized_with[1]).to eq(kwarg: "value")
    expect(initialized_with[2].call).to eq("block result")
  end
end
