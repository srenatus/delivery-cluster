class Chef
  class Provider
    class DeliveryChangeDb < Chef::Provider::LWRPBase
      use_inline_resources

      action :create do
        converge_by("Create Change Databag Item: #{change_id}") do
          new_resource.updated_by_last_action(create_databag)
        end
      end

      action :download do
        converge_by("Downloading Change Databag Item: #{change_id} to node.run_state['delivery']['change']['data']") do
          new_resource.updated_by_last_action(download_databag)
        end
      end

      private

      def change_id
        @change_id ||= new_resource.change_id
      end

      def data
        @data ||= new_resource.data
      end

      def data_attribute
        @data_attribute ||= new_resource.data_attribute
      end

      def create_databag
        # Create the data bag
        ::Chef_Delivery::ClientHelper.enter_client_mode_as_delivery
        begin
          bag = Chef::DataBag.new
          bag.name('changes')
          bag.create
        rescue Net::HTTPServerException => e
          if e.response.code == "409"
            ::Chef::Log.info("DataBag changes already exists.")
          else
            raise
          end
        end

        dbi_hash = {
          "id"       => change_id,
          "data" => data_hash
        }

        bag_item = Chef::DataBagItem.new
        bag_item.data_bag('changes')
        bag_item.raw_data = dbi_hash
        bag_item.save
        ::Chef::Log.info("Saved bag item #{dbi_hash} in data bag #{change_id}.")
        ::Chef_Delivery::ClientHelper.leave_client_mode_as_delivery
      end

      def download_databag
        ## TODO: Look at new delivery-truck syntax
        ::Chef_Delivery::ClientHelper.enter_client_mode_as_delivery
        node.run_state['delivery'] = {} if !node.run_state['delivery']
        node.run_state['delivery']['change'] = {} if !node.run_state['delivery']['change']
        node.run_state['delivery']['change']['data'] = data_bag_item('changes', change_id)
        ::Chef_Delivery::ClientHelper.leave_client_mode_as_delivery
      end

      def data_hash
        if data
          data
        else
          node.run_state['delivery']['change']['data']
        end
      end
    end
  end
end

class Chef
  class Resource
    class DeliveryChangeDb < Chef::Resource::LWRPBase
      actions :create, :download

      default_action :create

      attribute :change_id, :kind_of => String, :name_attribute => true, :required => true
      attribute :data, :kind_of => Hash

      self.resource_name = :delivery_change_db
      def initialize(name, run_context=nil)
        super
        @provider = Chef::Provider::DeliveryChangeDb
      end
    end
  end
end