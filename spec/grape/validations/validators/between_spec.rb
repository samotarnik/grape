require 'spec_helper'

describe Grape::Validations::BetweenValidator do
  class DTV   # datetime values
    class << self
      def from;    DateTime.new(2000,1,1,1,0,0); end
      def valid;   DateTime.new(2000,1,1,2,0,0); end
      def default; DateTime.new(2000,1,1,4,0,0); end
      def invalid; DateTime.new(2000,1,1,8,0,0); end
      def to; @to || DateTime.new(2000,1,1,7,0,0); end

      def endpoints
        [from, to]
      end

      def to= _to
        @to = _to
      end

      def method_missing(name, *args, &block)
        if name.to_s =~ /^s_(.*)$/
          send($1.to_sym).iso8601(3)
        end
      end
    end
  end

  module ValidationsSpec
    module BetweenValidatorSpec
      class API < Grape::API
        default_format :json

        params do
          requires :v, type: DateTime, between: DTV.endpoints
        end
        get '/' do
          { v: params[:v] }
        end

        params do
          optional :v, type: DateTime, between: DTV.endpoints, default: DTV.default
        end
        get '/default/valid' do
          { v: params[:v] }
        end

        params do
          optional :v, type: DateTime, between: [-> {DTV.from}, -> {DTV.to}], default: DTV.default
        end
        get '/lambda' do
          { v: params[:v] }
        end

        params do
          optional :v, type: DateTime, between: DTV.endpoints, default: -> { DTV.valid }
        end
        get '/default_lambda' do
          { v: params[:v] }
        end

        params do
          optional :v, type: DateTime, between: -> { DTV.endpoints }, default: -> { DTV.default }
        end
        get '/default_and_values_lambda' do
          { v: params[:v] }
        end

        params do
          requires :v, type: Integer, desc: 'An integer', between: [8,12], default: 10
        end
        get '/values/coercion' do
          { v: params[:v] }
        end

        params do
          requires :v, type: Array[Integer], desc: 'An integer', between: [8,12], default: 10
        end
        get '/values/array_coercion' do
          { v: params[:v] }
        end

        params do
          optional :optional, type: Array do
            requires :v, between: %w(a b)
          end
        end
        get '/optional_with_required_values'
      end
    end
  end

  def app
    ValidationsSpec::BetweenValidatorSpec::API
  end

  it 'allows a valid value for a parameter' do
    val = DTV.s_default
    get('/', v: val)
    expect(last_response.status).to eq 200
    expect(last_response.body).to eq({ v: val }.to_json)
  end

  it 'does not allow an invalid value for a parameter' do
    get('/', v: DTV.s_invalid)
    expect(last_response.status).to eq 400
    expect(last_response.body).to eq({ error: 'v does not have a valid value' }.to_json)
  end

  context 'nil value for a parameter' do
    it 'does not allow for root params scope' do
      get('/', v: nil)
      expect(last_response.status).to eq 400
      expect(last_response.body).to eq({ error: 'v does not have a valid value' }.to_json)
    end

    it 'allows for a required param in child scope' do
      get('/optional_with_required_values')
      expect(last_response.status).to eq 200
    end
  end

  it 'allows a valid default value' do
    get('/default/valid')
    expect(last_response.status).to eq 200
    expect(last_response.body).to eq({ v: DTV.s_default }.to_json)
  end

  it 'allows a proc for between endpoints' do
    val = DTV.s_valid
    get('/lambda', v: val)
    expect(last_response.status).to eq 200
    expect(last_response.body).to eq({ v: val }.to_json)
  end

  it 'does not validate updated endpoints without a proc' do
    DTV.to = DateTime.new(2000,1,1,9,0,0)

    get('/', v: DTV.s_invalid)
    expect(last_response.status).to eq 400
    expect(last_response.body).to eq({ error: 'v does not have a valid value' }.to_json)

    DTV.to = nil
  end

  it 'validates against endpoints in a proc' do
    DTV.to = DateTime.new(2000,1,1,9,0,0)

    val = DTV.s_invalid
    get('/lambda', v: val)
    expect(last_response.status).to eq 200
    expect(last_response.body).to eq({ v: val }.to_json)

    DTV.to = nil
  end

  it 'does not allow an invalid value for a parameter using lambda' do
    val = DTV.s_invalid
    get('/lambda', v: val)
    expect(last_response.status).to eq 400
    expect(last_response.body).to eq({ error: 'v does not have a valid value' }.to_json)
  end

  it 'validates default value from a proc' do
    get('/default_lambda')
    expect(last_response.status).to eq 200
  end

  it 'validates default value from proc against endpoints in a proc' do
    get('/default_and_values_lambda')
    expect(last_response.status).to eq 200
  end

  it 'raises IncompatibleOptionValues on an invalid default value from proc' do
    subject = Class.new(Grape::API)
    expect do
      subject.params { optional :v, type: DateTime, between: DTV.endpoints, default: DTV.valid+345 }
    end.to raise_error Grape::Exceptions::IncompatibleOptionValues
  end

  it 'raises IncompatibleOptionValues on an invalid default value' do
    subject = Class.new(Grape::API)
    expect do
      subject.params { optional :v, between: DTV.endpoints, default: DTV.invalid }
    end.to raise_error Grape::Exceptions::IncompatibleOptionValues
  end

  it 'raises IncompatibleOptionValues when type is incompatible with endpoints' do
    subject = Class.new(Grape::API)
    expect do
      subject.params { optional :type, values: ['valid-type1', 'valid-type2', 'valid-type3'], type: Symbol }
    end.to raise_error Grape::Exceptions::IncompatibleOptionValues
  end

  it 'allows values to be a kind of the coerced type not just an instance of it' do
    get('/values/coercion', v: 11)
    expect(last_response.status).to eq 200
    expect(last_response.body).to eq({ v: 11}.to_json)
  end

  it 'allows values to be a kind of the coerced type in an array' do
    get('/values/array_coercion', v: [11])
    expect(last_response.status).to eq 200
    expect(last_response.body).to eq({ v: [11] }.to_json)
  end

  it 'raises IncompatibleOptionValues when endpoints contains a value that is not a kind of the type' do
    subject = Class.new(Grape::API)
    expect do
      subject.params { requires :v, between: [8.5, 11], type: Integer }
    end.to raise_error Grape::Exceptions::IncompatibleOptionValues
  end

  context 'with a lambda values' do
    subject do
      Class.new(Grape::API) do
        params do
          optional :v, type: Integer, between: [-> {rand(1..3)}, 10], default: -> {rand(5..8)}
        end
        get '/random_values'
      end
    end

    def app
      subject
    end

    before do
      expect_any_instance_of(Object).to receive(:rand).and_return(4)
    end

    it 'only evaluates endpoints dynamically with each request' do
      get '/random_values', v: 7
      expect(last_response.status).to eq 200
    end

    it 'chooses default' do
      get '/random_values'
      expect(last_response.status).to eq 200
    end
  end

  context 'with a range for endpoints' do
    subject(:app) do
      Class.new(Grape::API) do
        params do
          optional :v, type: Float, between: 0.0..10.0
        end
        get '/value' do
          { v: params[:v] }.to_json
        end

        params do
          optional :v, type: Array[Float], between: 0.0..10.0
        end
        get '/values' do
          { v: params[:v] }.to_json
        end
      end
    end

    it 'allows a single value inside of the range' do
      get('/value', v: 5.2)
      expect(last_response.status).to eq 200
      expect(last_response.body).to eq({ v: 5.2 }.to_json)
    end

    it 'allows an array of values inside of the range' do
      get('/values', v: [8.6, 7.5, 3, 0.9])
      expect(last_response.status).to eq 200
      expect(last_response.body).to eq({ v: [8.6, 7.5, 3.0, 0.9] }.to_json)
    end

    it 'rejects a single value outside the range' do
      get('/value', v: 'a')
      expect(last_response.status).to eq 400
      expect(last_response.body).to eq('v is invalid, v does not have a valid value')
    end

    it 'rejects an array of values if any of them are outside the range' do
      get('/values', v: [8.6, 75, 3, 0.9])
      expect(last_response.status).to eq 400
      expect(last_response.body).to eq('v does not have a valid value')
    end
  end
end
