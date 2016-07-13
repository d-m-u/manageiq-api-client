module ManageIQ
  module API
    module Client
      class Server
        attr_accessor :options
        attr_accessor :url
        attr_accessor :authentication
        attr_accessor :connection

        attr_accessor :api
        attr_accessor :settings
        attr_accessor :identity
        attr_accessor :authorization
        attr_accessor :collections

        DEFAULTS = {
          :url => "http://localhost:3000"
        }.freeze

        def initialize(options = {})
          @options = options.dup
          @url = options[:url] || DEFAULTS[:url]
          begin
            URI.parse(url)
          rescue
            raise "Malformed ManageIQ Appliance URL #{url} specified"
          end

          @authentication = ManageIQ::API::Client::Authentication.new(options)
          @connection = ManageIQ::API::Client::Connection.new(url, authentication)
          load_definitions
        end

        def load_definitions
          entrypoint     = connection.get("", :attributes => "authorization")
          @api           = ManageIQ::API::Client::ServerApi.new(entrypoint)
          @settings      = entrypoint["settings"].dup
          @identity      = ManageIQ::API::Client::Identity.new(entrypoint["identity"])
          @authorization = Hash(entrypoint["authorization"]).dup
          @collections   = load_collections(entrypoint["collections"])
        end

        delegate :get, :post, :put, :patch, :delete, :error, :to => :connection

        private

        def load_collections(collection_list)
          collection_list.collect do |collection_def|
            collection_name = collection_def["name"]
            klass_name = collection_name.classify

            if ManageIQ::API::Client::Collection.const_defined?(klass_name)
              klass = ManageIQ::API::Client::Collection.const_get(klass_name)
            else
              klass = Class.new(ManageIQ::API::Client::Collection) do
                attr_accessor :name
                attr_accessor :href
                attr_accessor :description
                attr_accessor :actions

                def initialize(server, collection_spec)
                  @name        = collection_spec["name"]
                  @href        = collection_spec["href"]
                  @description = collection_spec["description"]
                  clear_actions
                  super(server)
                end
              end

              ManageIQ::API::Client::Collection.const_set(klass_name, klass)
            end

            collection = klass.new(self, collection_def)
            create_method(collection.name.to_sym) { collection }
            collection
          end
        end

        def create_method(name, &block)
          self.class.send(:define_method, name, &block)
        end
      end
    end
  end
end
