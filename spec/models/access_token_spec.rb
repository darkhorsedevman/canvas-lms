 #
# Copyright (C) 2012 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

describe AccessToken do
  context "hashed tokens" do
    before :once do
      @at = AccessToken.create!(:user => user_model, :developer_key => DeveloperKey.default)
      @token_string = @at.full_token
      @refresh_token_string = @at.plaintext_refresh_token
    end

    it "should only store the encrypted token" do
      expect(@token_string).to be_present
      expect(@token_string).not_to eq @at.crypted_token
      expect(AccessToken.find(@at.id).full_token).to be_nil
    end

    it "should authenticate via crypted_token" do
      expect(AccessToken.authenticate(@token_string)).to eq @at
    end

    it "shouldn't auth old tokens after regeneration" do
      expect(AccessToken.authenticate(@token_string)).to eq @at
      @at.regenerate_access_token
      new_token_string = @at.full_token

      expect(new_token_string).to_not eq @token_string
      expect(AccessToken.authenticate(new_token_string)).to eq @at

      expect(AccessToken.authenticate(@token_string)).to_not eq @at
    end

    it "should not authenticate expired tokens" do
      @at.update_attribute(:expires_at, 2.hours.ago)
      expect(AccessToken.authenticate(@token_string)).to be_nil
    end

    it "should authenticate via crypted_token" do
      expect(AccessToken.authenticate_refresh_token(@refresh_token_string)).to eq @at
    end

    it "should authenticate expired tokens by the refresh token" do
      @at.update_attribute(:expires_at, 2.hours.ago)
      expect(AccessToken.authenticate_refresh_token(@refresh_token_string)).to eq @at
    end
  end

  describe "usable?" do
    before :once do
      @at = AccessToken.create!(:user => user_model, :developer_key => DeveloperKey.default)
      @token_string = @at.full_token
      @refresh_token_string = @at.plaintext_refresh_token
    end


    it "shouldn't be usable without proper fields" do
      token = AccessToken.new
      expect(token.usable?).to eq false
    end

    it "Should be usable" do
      expect(@at.usable?).to eq true
    end

    it "Should be usable without dev key" do
      @at.developer_key_id = nil
      expect(@at.usable?).to eq true
    end

    it "Shouldn't be usable if expired" do
      @at.update_attribute(:expires_at, 2.hours.ago)
      expect(@at.usable?).to eq false
    end

    it "Should be usable if expired, but requesting with a refresh_token" do
      @at.update_attribute(:expires_at, 2.hours.ago)
      expect(@at.usable?(:crypted_refresh_token)).to eq true
    end

    it "Shouldn't be usable if dev key isn't active" do

      dk = DeveloperKey.create!(account: account_model)
      dk.deactivate
      @at.developer_key = dk
      @at.save

      expect(@at.usable?).to eq false
    end

    it "Shouldn't be usable if dev key isn't active, even if we request with a refresh token" do

      dk = DeveloperKey.create!(account: account_model)
      dk.deactivate
      @at.developer_key = dk
      @at.save

      expect(@at.usable?(:crypted_refresh_token)).to eq false
    end
  end

  describe "token scopes" do
    let_once(:token) do
      token = AccessToken.new
      token.scopes = %w{https://canvas.instructure.com/login/oauth2/auth/user_profile https://canvas.instructure.com/login/oauth2/auth/accounts}
      token
    end

    it "should match named scopes" do
      expect(token.scoped_to?(['https://canvas.instructure.com/login/oauth2/auth/user_profile', 'accounts'])).to eq true
    end

    it "should not partially match scopes" do
      expect(token.scoped_to?(['user', 'accounts'])).to eq false
      expect(token.scoped_to?(['profile', 'accounts'])).to eq false
    end

    it "should not match if token has more scopes then requested" do
      expect(token.scoped_to?(['user_profile', 'accounts', 'courses'])).to eq false
    end

    it "should not match if token has less scopes then requested" do
      expect(token.scoped_to?(['user_profile'])).to eq false
    end
  end

  describe "account scoped access" do

    before :once do
      @ac = account_model
      @sub_ac = @ac.sub_accounts.create!
      @foreign_ac = Account.create!

      @dk = DeveloperKey.create!(account: @ac)
      @at = AccessToken.create!(:user => user_model, :developer_key => @dk)

      @dk_without_account = DeveloperKey.create!
      @at_without_account = AccessToken.create!(:user => user_model, :developer_key => @dk2)
    end

    it "account should be set" do
      expect(@at.account.id).to be @ac.id
    end

    it "account should be authorized" do
      expect(@at.authorized_for_account?(@ac)).to be true
    end

    it "sub account should be authorized" do
      expect(@at.authorized_for_account?(@sub_ac)).to be true
    end
    it "account should be the account from the developer key" do
      expect(@at.account.id).to be @dk.account.id
    end

    it "account should be nil" do
      expect(@at_without_account.account).to be nil
    end

    it "foreign account should not be authorized" do
      expect(@at.authorized_for_account?(@foreign_ac)).to be false
    end

    it "foreign account should be authorized if there is no account" do
      expect(@at_without_account.authorized_for_account?(@foreign_ac)).to be true
    end
  end
end
