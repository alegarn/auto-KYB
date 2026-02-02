require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      user = User.new(email: "test@example.com", password: "password123456")
      expect(user).to be_valid
    end

    it "requires an email" do
      user = User.new(email: nil)
      expect(user).to be_invalid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it "requires a unique email" do
      existing_user = User.create(email: "test@example.com", password: "password123456")
      expect(existing_user).to be_persisted

      duplicate_user = User.new(email: "test@example.com", password: "password123456")
      expect(duplicate_user).to be_invalid
      expect(duplicate_user.errors[:email]).to include("has already been taken")
    end

    it "requires a valid email format" do
      user = User.new(email: "invalid-email", password: "password123456")
      expect(user).to be_invalid
      expect(user.errors[:email]).to include("is invalid")
    end

    it "requires password to be at least 12 characters" do
      user = User.new(email: "test@example.com", password: "short")
      expect(user).to be_invalid
      expect(user.errors[:password]).to include("is too short (minimum is 12 characters)")
    end

    it "allows password to be nil when updating existing user" do
      user = User.create!(email: "test@example.com", password: "password123456")
      user.password = nil
      expect(user).to be_valid
    end

    it "sets verified to false by default" do
      user = User.create(email: "test@example.com", password: "password123456")
      expect(user.verified).to be false
    end
  end

  describe "normalizations" do
    it "strips and downcases email on create" do
      user = User.create(email: "  TEST@EXAMPLE.COM  ", password: "password123456")
      expect(user.email).to eq("test@example.com")
    end

    it "strips and downcases email on update" do
      user = User.create!(email: "test@example.com", password: "password123456")
      user.update(email: "  NEW@EXAMPLE.COM  ")
      expect(user.email).to eq("new@example.com")
    end
  end

  describe "associations" do
    it "has many sessions" do
      user = User.create!(email: "test@example.com", password: "password123456")
      session1 = user.sessions.create!
      session2 = user.sessions.create!

      expect(user.sessions).to include(session1, session2)
    end

    it "destroys sessions when user is destroyed" do
      user = User.create!(email: "test@example.com", password: "password123456")
      session = user.sessions.create!

      expect { user.destroy }.to change { Session.count }.by(-1)
    end
  end

  describe "callbacks" do
    context "when email changes" do
      it "sets verified to false" do
        user = User.create!(email: "test@example.com", password: "password123456", verified: true)
        user.update(email: "newemail@example.com")

        expect(user.verified).to be false
      end

      it "does not set verified to false when email does not change" do
        user = User.create!(email: "test@example.com", password: "password123456", verified: true)
        user.update(email: "test@example.com")

        expect(user.verified).to be true
      end

      it "sets verified to false when email casing changes" do
        user = User.create!(email: "test@example.com", password: "password123456", verified: true)
        user.update(email: "TEST@EXAMPLE.COM")

        expect(user.verified).to be false
      end
    end

    context "when password changes" do
      it "deletes other sessions but preserves current session" do
        user = User.create!(email: "test@example.com", password: "password123456")
        current_session = user.sessions.create!
        other_session = user.sessions.create!

        Current.session = current_session
        user.update(password: "newpassword123456")

        expect(Session.exists?(current_session.id)).to be true
        expect(Session.exists?(other_session.id)).to be false
      end

      it "does not delete sessions when password does not change" do
        user = User.create!(email: "test@example.com", password: "password123456")
        session1 = user.sessions.create!
        session2 = user.sessions.create!

        user.update(email: "newemail@example.com")

        expect(Session.exists?(session1.id)).to be true
        expect(Session.exists?(session2.id)).to be true
      end
    end
  end

  describe "#email_verification_token" do
    it "generates a token for email verification" do
      user = User.create!(email: "test@example.com", password: "password123456")
      token = user.generate_token_for(:email_verification)

      expect(token).to be_present
    end

    it "finds user by valid email verification token" do
      user = User.create!(email: "test@example.com", password: "password123456")
      token = user.generate_token_for(:email_verification)

      found_user = User.find_by_token_for(:email_verification, token)
      expect(found_user).to eq(user)
    end

    it "does not find user by expired email verification token" do
      user = User.create!(email: "test@example.com", password: "password123456")
      token = user.generate_token_for(:email_verification)

      travel_to(3.days.from_now) do
        found_user = User.find_by_token_for(:email_verification, token)
        expect(found_user).to be_nil
      end
    end
  end

  describe "#password_reset_token" do
    it "generates a token for password reset" do
      user = User.create!(email: "test@example.com", password: "password123456")
      token = user.generate_token_for(:password_reset)

      expect(token).to be_present
    end

    it "finds user by valid password reset token" do
      user = User.create!(email: "test@example.com", password: "password123456")
      token = user.generate_token_for(:password_reset)

      found_user = User.find_by_token_for(:password_reset, token)
      expect(found_user).to eq(user)
    end

    it "does not find user by expired password reset token" do
      user = User.create!(email: "test@example.com", password: "password123456")
      token = user.generate_token_for(:password_reset)

      travel_to(21.minutes.from_now) do
        found_user = User.find_by_token_for(:password_reset, token)
        expect(found_user).to be_nil
      end
    end
  end

  describe ".authenticate_by" do
    it "authenticates user with correct credentials" do
      user = User.create!(email: "test@example.com", password: "password123456")
      authenticated_user = User.authenticate_by(email: "test@example.com", password: "password123456")

      expect(authenticated_user).to eq(user)
    end

    it "does not authenticate with incorrect email" do
      User.create!(email: "test@example.com", password: "password123456")
      authenticated_user = User.authenticate_by(email: "wrong@example.com", password: "password123456")

      expect(authenticated_user).to be_nil
    end

    it "does not authenticate with incorrect password" do
      User.create!(email: "test@example.com", password: "password123456")
      authenticated_user = User.authenticate_by(email: "test@example.com", password: "wrongpassword")

      expect(authenticated_user).to be_nil
    end

    it "does not authenticate with nil password" do
      User.create!(email: "test@example.com", password: "password123456")
      authenticated_user = User.authenticate_by(email: "test@example.com", password: nil)

      expect(authenticated_user).to be_nil
    end

    it "authenticates with normalized email" do
      user = User.create!(email: "test@example.com", password: "password123456")
      authenticated_user = User.authenticate_by(email: "  TEST@EXAMPLE.COM  ", password: "password123456")

      expect(authenticated_user).to eq(user)
    end
  end
end
