#
# Copyright (C) 2018 - present Instructure, Inc.
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

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

RSpec.describe Lti::ToolConfigurationsApiController, type: :controller do
  let_once(:account) { account_model }
  let_once(:admin) { account_admin_user(account: account) }
  let_once(:student) do
    student_in_course
    @student
  end

  let(:developer_key) { DeveloperKey.create!(account: account) }

  let(:config_from_response) do
    Lti::ToolConfiguration.find(json_parse.dig('tool_configuration', 'id'))
  end

  let(:tool_configuration) do
    Lti::ToolConfiguration.create!(
      developer_key: developer_key,
      settings: { foo: 'bar' }
    )
  end

  let(:settings) do
    {
      'foo' => 'bar',
      'banana' => {'test' => '1'},
      'something' => ['test', 'value']
    }
  end

  let(:valid_parameters) do
    {
      developer_key_id: developer_key.id,
      tool_configuration: {
          settings: settings
      }
    }
  end

  before { user_session(admin) }

  shared_examples_for 'an action that requires manage developer keys' do
    let(:response) { raise 'set in example' }

    it 'does not render "unauthorized" if the user has manage_developer_keys' do
      expect(response).to be_success
    end

    context 'when the user is not an admin' do
      before { user_session(student) }

      it 'renders "unauthorized" if the user does not have manage_developer_keys' do
        expect(response).to be_unauthorized
      end
    end

    context 'when the developer key does not exist' do
      before { developer_key.destroy! }

      it { is_expected.to be_not_found }
    end
  end

  shared_examples_for 'an endpoint that requires an existing tool configuraiton' do
    let(:response) { raise 'set in example' }

    context 'when the tool configuration does not exist' do
      it { is_expected.to be_not_found }
    end
  end

  describe 'create_or_update' do
    subject { post :create_or_update, params: valid_parameters }

    it_behaves_like 'an action that requires manage developer keys' do
      let(:response) { subject }
    end

    context 'when the tool configuration does not exist' do
      it { is_expected.to be_ok }
    end

    context 'when the tool configuration already exists' do
      before do
        tool_configuration
        subject
      end

      it { is_expected.to be_ok }

      it 'updates the tool configuration' do
        new_settings = config_from_response.settings
        expect(new_settings).to eq valid_parameters.dig(:tool_configuration, :settings)
      end
    end
  end

  describe 'show' do
    subject { get :show, params: valid_parameters.except(:tool_configuration) }

    let(:show_response) do
      tool_configuration
      subject
    end

    it_behaves_like 'an action that requires manage developer keys' do
      let(:response) { show_response }
    end

    it_behaves_like 'an endpoint that requires an existing tool configuraiton' do
      let(:response) { show_response }
    end

    context 'when the tool configuration exists' do
      before do
        tool_configuration
        subject
      end

      it 'renders the tool configuration' do
        expect(config_from_response).to eq tool_configuration
      end
    end
  end

  describe 'destroy' do
    subject { delete :destroy, params: valid_parameters.except(:tool_configuration) }

    let(:destroy_response) do
      tool_configuration
      subject
    end

    it_behaves_like 'an action that requires manage developer keys' do
      let(:response) { destroy_response }
    end

    it_behaves_like 'an endpoint that requires an existing tool configuraiton' do
      let(:response) { destroy_response }
    end

    context 'when the tool configuration exists' do
      before do
        tool_configuration
        subject
      end

      it 'destroys the tool configuration' do
        expect(Lti::ToolConfiguration.find_by(id: tool_configuration.id)).to be_nil
      end

      it { is_expected.to be_no_content }
    end
  end
end
