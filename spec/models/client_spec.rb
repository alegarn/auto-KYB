require "rails_helper"

RSpec.describe Client, type: :model do
  describe "validations" do
    it "is valid with all required attributes" do
      user = create(:user)
      client = build(:client, user: user)
      expect(client).to be_valid
    end

    context "when name is missing" do
      it "is invalid" do
        user = create(:user)
        client = build(:client, user: user, name: nil)
        expect(client).to be_invalid
        expect(client.errors[:name]).to include("can't be blank")
      end
    end

    context "when company_name is missing" do
      it "is invalid" do
        user = create(:user)
        client = build(:client, user: user, company_name: nil)
        expect(client).to be_invalid
        expect(client.errors[:company_name]).to include("can't be blank")
      end
    end

    context "when email is invalid" do
      it "is invalid" do
        user = create(:user)
        client = build(:client, user: user, email: "invalid-email")
        expect(client).to be_invalid
        expect(client.errors[:email]).to include("is invalid")
      end
    end

    context "when email is blank" do
      it "is valid" do
        user = create(:user)
        client = build(:client, user: user, email: nil)
        expect(client).to be_valid
      end
    end

    context "when email is valid" do
      it "is valid" do
        user = create(:user)
        client = build(:client, user: user, email: "valid@example.com")
        expect(client).to be_valid
      end
    end

    context "when phone is invalid" do
      it "is invalid" do
        user = create(:user)
        client = build(:client, user: user, phone: "123")
        expect(client).to be_invalid
        expect(client.errors[:phone]).to include("is invalid")
      end
    end

    context "when phone is blank" do
      it "is valid" do
        user = create(:user)
        client = build(:client, user: user, phone: nil)
        expect(client).to be_valid
      end
    end

    context "when phone is valid" do
      it "is valid" do
        user = create(:user)
        client = build(:client, user: user, phone: "+1 (555) 123-4567")
        expect(client).to be_valid
      end
    end

    context "when phone has various valid formats" do
      it "is valid with international format" do
        user = create(:user)
        client = build(:client, user: user, phone: "+33123456789")
        expect(client).to be_valid
      end

      it "is valid with spaces" do
        user = create(:user)
        client = build(:client, user: user, phone: "555 123 4567")
        expect(client).to be_valid
      end

      it "is valid with dashes" do
        user = create(:user)
        client = build(:client, user: user, phone: "555-123-4567")
        expect(client).to be_valid
      end

      it "is valid with parentheses" do
        user = create(:user)
        client = build(:client, user: user, phone: "(555) 123-4567")
        expect(client).to be_valid
      end
    end
  end

  describe "associations" do
    it "belongs to a user" do
      user = create(:user)
      client = create(:client, user: user)
      expect(client.user).to eq(user)
    end

    it "requires a user" do
      client = build(:client, user: nil)
      expect(client).to be_invalid
      expect(client.errors[:user]).to include("must exist")
    end
  end

  describe "scopes" do
    describe ".by_user" do
      it "includes clients for the specified user" do
        user1 = create(:user)
        user2 = create(:user)
        client1 = create(:client, user: user1)
        client2 = create(:client, user: user2)

        result = Client.by_user(user1.id)
        expect(result).to include(client1)
        expect(result).not_to include(client2)
      end

      it "excludes clients for other users" do
        user1 = create(:user)
        user2 = create(:user)
        create(:client, user: user1)
        client2 = create(:client, user: user2)

        result = Client.by_user(user1.id)
        expect(result).not_to include(client2)
      end

      it "returns empty when user has no clients" do
        user = create(:user)
        create(:client) # Create a client for a different user

        result = Client.by_user(user.id)
        expect(result).to be_empty
      end
    end

    describe ".search_by_name_or_company" do
      before do
        @user = create(:user)
        @client1 = create(:client, user: @user, name: "John Doe", company_name: "Acme Corp")
        @client2 = create(:client, user: @user, name: "Jane Smith", company_name: "Beta Industries")
        @client3 = create(:client, user: @user, name: "Bob Johnson", company_name: "Acme Solutions")
        @client4 = create(:client, user: create(:user), name: "John Doe", company_name: "Other Corp")
      end

      context "when searching by name" do
        it "includes clients matching the name" do
          result = Client.search_by_name_or_company("john")
          expect(result).to include(@client1, @client3)
        end

        it "is case-insensitive" do
          result = Client.search_by_name_or_company("JOHN")
          expect(result).to include(@client1, @client3)
        end

        it "excludes clients not matching the name" do
          result = Client.search_by_name_or_company("john")
          expect(result).not_to include(@client2)
        end
      end

      context "when searching by company name" do
        it "includes clients matching the company name" do
          result = Client.search_by_name_or_company("acme")
          expect(result).to include(@client1, @client3)
        end

        it "is case-insensitive" do
          result = Client.search_by_name_or_company("ACME")
          expect(result).to include(@client1, @client3)
        end

        it "excludes clients not matching the company name" do
          result = Client.search_by_name_or_company("acme")
          expect(result).not_to include(@client2)
        end
      end

      context "when query matches both name and company" do
        it "includes all matching clients" do
          result = Client.search_by_name_or_company("acme")
          expect(result).to include(@client1, @client3)
        end
      end

      context "when query is nil" do
        it "returns all clients" do
          result = Client.search_by_name_or_company(nil)
          expect(result.count).to eq(Client.count)
        end
      end

      context "when query is empty string" do
        it "returns all clients" do
          result = Client.search_by_name_or_company("")
          expect(result.count).to eq(Client.count)
        end
      end

      context "when query matches no clients" do
        it "returns empty collection" do
          result = Client.search_by_name_or_company("nonexistent")
          expect(result).to be_empty
        end
      end
    end
  end

  describe "address field" do
    it "stores address as JSONB" do
      user = create(:user)
      address_data = { "street" => "123 Main St", "city" => "New York", "country" => "USA" }
      client = create(:client, user: user, address: address_data)

      expect(client.address).to eq(address_data)
    end

    it "allows nil address" do
      user = create(:user)
      client = create(:client, user: user, address: nil)

      expect(client.address).to be_nil
    end

    it "allows empty address hash" do
      user = create(:user)
      client = create(:client, user: user, address: {})

      expect(client.address).to eq({})
    end
  end
end
