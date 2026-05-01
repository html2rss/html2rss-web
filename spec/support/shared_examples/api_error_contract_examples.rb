# frozen_string_literal: true

RSpec.shared_examples 'api error contract' do |expected|
  it "returns #{expected.fetch(:status)} with #{expected.fetch(:code)} error payload", :aggregate_failures do # rubocop:disable RSpec/ExampleLength
    perform_request.call

    expect(last_response.status).to eq(expected.fetch(:status))
    expect(last_response.content_type).to include('application/json')
    json = expect_error_response(
      last_response,
      code: expected.fetch(:code),
      kind: expected.fetch(:kind),
      retryable: expected.fetch(:retryable),
      next_action: expected.fetch(:next_action),
      retry_action: expected.fetch(:retry_action, 'none')
    )
    expected_message = expected[:message]
    expect(json.dig('error', 'message')).to eq(expected_message) if expected_message
  end
end
