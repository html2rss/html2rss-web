# frozen_string_literal: true

RSpec.shared_examples 'api error contract' do |status:, code:, message: nil|
  it "returns #{status} with #{code} error payload", :aggregate_failures do
    perform_request.call

    expect(last_response.status).to eq(status)
    expect(last_response.content_type).to include('application/json')
    json = expect_error_response(last_response, code: code)
    expect(json.dig('error', 'message')).to eq(message) if message
  end
end
