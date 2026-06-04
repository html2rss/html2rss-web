# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require "traces/provider"
require_relative "../../../../protocol/http2/framer"

Traces::Provider(Protocol::HTTP2::Framer) do
	def write_connection_preface
		return super unless Traces.active?
		
		Traces.trace("protocol.http2.framer.write_connection_preface") do
			super
		end
	end
	
	def read_connection_preface
		return super unless Traces.active?
		
		Traces.trace("protocol.http2.framer.read_connection_preface") do
			super
		end
	end
	
	def write_frame(frame)
		return super unless Traces.active?
		
		attributes = {
			"frame.length" => frame.length,
			"frame.class" => frame.class.name,
			"frame.type" => frame.type,
			"frame.flags" => frame.flags,
			"frame.stream_id" => frame.stream_id,
		}
		
		Traces.trace("protocol.http2.framer.write_frame", attributes: attributes) do
			super
		end
	end
	
	def read_frame(...)
		return super unless Traces.active?
		
		Traces.trace("protocol.http2.framer.read_frame") do |span|
			super.tap do |frame|
				span["frame.length"] = frame.length
				span["frame.type"] = frame.type
				span["frame.flags"] = frame.flags
				span["frame.stream_id"] = frame.stream_id
			end
		end
	end
	
	def flush
		return super unless Traces.active?
		
		Traces.trace("protocol.http2.framer.flush") do
			super
		end
	end
end
