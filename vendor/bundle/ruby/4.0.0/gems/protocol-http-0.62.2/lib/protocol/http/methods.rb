# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.

module Protocol
	module HTTP
		# Provides a convenient interface for commonly supported HTTP methods.
		#
		# | Method Name | Request Body | Response Body | Safe | Idempotent | Cacheable |
		# | ----------- | ------------ | ------------- | ---- | ---------- | --------- |
		# | GET         | Optional     | Yes           | Yes  | Yes        | Yes       |
		# | HEAD        | Optional     | No            | Yes  | Yes        | Yes       |
		# | POST        | Yes          | Yes           | No   | No         | Yes       |
		# | PUT         | Yes          | Yes           | No   | Yes        | No        |
		# | DELETE      | Optional     | Yes           | No   | Yes        | No        |
		# | CONNECT     | Optional     | Yes           | No   | No         | No        |
		# | OPTIONS     | Optional     | Yes           | Yes  | Yes        | No        |
		# | TRACE       | No           | Yes           | Yes  | Yes        | No        |
		# | PATCH       | Yes          | Yes           | No   | No         | No        |
		#
		# These methods are defined in this module using lower case names. They are for convenience only and you should not overload those methods.
		#
		# See <https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods> for more details.
		class Methods
			# The GET method requests a representation of the specified resource. Requests using GET should only retrieve data.
			GET = "GET"
			
			# The HEAD method asks for a response identical to a GET request, but without the response body.
			HEAD = "HEAD"
			
			# The POST method submits an entity to the specified resource, often causing a change in state or side effects on the server.
			POST = "POST"
			
			# The PUT method replaces all current representations of the target resource with the request payload.
			PUT = "PUT"
			
			# The DELETE method deletes the specified resource.
			DELETE = "DELETE"
			
			# The CONNECT method establishes a tunnel to the server identified by the target resource.
			CONNECT = "CONNECT"
			
			# The OPTIONS method describes the communication options for the target resource.
			OPTIONS = "OPTIONS"
			
			# The TRACE method performs a message loop-back test along the path to the target resource.
			TRACE = "TRACE"
			
			# The PATCH method applies partial modifications to a resource.
			PATCH = "PATCH"
			
			# Check if the given name is a valid HTTP method, according to this module.
			#
			# Note that this method only knows about the methods defined in this module, however there are many other methods defined in different specifications.
			#
			# @returns [Boolean] True if the name is a valid HTTP method.
			def self.valid?(name)
				const_defined?(name)
			rescue NameError
				# Ruby will raise an exception if the name is not valid for a constant.
				return false
			end
			
			# Enumerate all HTTP methods.
			# @yields {|name, value| ...}
			# 	@parameter name [Symbol] The name of the method, e.g. `:GET`.
			# 	@parameter value [String] The value of the method, e.g. `"GET"`.
			def self.each
				return to_enum(:each) unless block_given?
				
				constants.each do |name|
					yield name.downcase, const_get(name)
				end
			end
			
			self.each do |name, method|
				define_method(name) do |*arguments, **options|
					self.call(
						Request[method, *arguments, **options]
					)
				end
			end
		end
	end
end
