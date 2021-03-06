# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "delegate"

module Google
  module Cloud
    module Storage
      class File
        ##
        # File::List is a special case Array with additional values.
        class List < DelegateClass(::Array)
          ##
          # If not empty, indicates that there are more files that match the
          # request and this value should be passed to the next
          # {Google::Cloud::Storage::Bucket#files} to continue.
          attr_accessor :token

          # The list of prefixes of objects matching-but-not-listed up to and
          # including the requested delimiter.
          attr_accessor :prefixes

          ##
          # @private Create a new File::List with an array of values.
          def initialize arr = []
            super arr
          end

          ##
          # Whether there is a next page of files.
          #
          # @return [Boolean]
          #
          # @example
          #   require "google/cloud"
          #
          #   gcloud = Google::Cloud.new
          #   storage = gcloud.storage
          #
          #   bucket = storage.bucket "my-bucket"
          #   files = bucket.files
          #   if files.next?
          #     next_files = files.next
          #   end
          #
          def next?
            !token.nil?
          end

          ##
          # Retrieve the next page of files.
          #
          # @return [File::List]
          #
          # @example
          #   require "google/cloud"
          #
          #   gcloud = Google::Cloud.new
          #   storage = gcloud.storage
          #
          #   bucket = storage.bucket "my-bucket"
          #   files = bucket.files
          #   if files.next?
          #     next_files = files.next
          #   end
          #
          def next
            return nil unless next?
            ensure_service!
            options = {
              prefix: @prefix, delimiter: @delimiter, token: @token, max: @max,
              versions: @versions
            }
            gapi = @service.list_files @bucket, options
            File::List.from_gapi gapi, @service, @bucket, @prefix,
                                 @delimiter, @max, @versions
          end

          ##
          # Retrieves all files by repeatedly loading {#next} until {#next?}
          # returns `false`. Calls the given block once for each file, which is
          # passed as the parameter.
          #
          # An Enumerator is returned if no block is given.
          #
          # This method may make several API calls until all files are
          # retrieved. Be sure to use as narrow a search criteria as possible.
          # Please use with caution.
          #
          # @param [Integer] request_limit The upper limit of API requests to
          #   make to load all files. Default is no limit.
          # @yield [file] The block for accessing each file.
          # @yieldparam [File] file The file object.
          #
          # @return [Enumerator]
          #
          # @example Iterating each file by passing a block:
          #   require "google/cloud"
          #
          #   gcloud = Google::Cloud.new
          #   storage = gcloud.storage
          #
          #   bucket = storage.bucket "my-bucket"
          #   files = bucket.files
          #   files.all do |file|
          #     puts file.name
          #   end
          #
          # @example Using the enumerator by not passing a block:
          #   require "google/cloud"
          #
          #   gcloud = Google::Cloud.new
          #   storage = gcloud.storage
          #
          #   bucket = storage.bucket "my-bucket"
          #   files = bucket.files
          #
          #   all_names = files.all.map do |file|
          #     file.name
          #   end
          #
          # @example Limit the number of API calls made:
          #   require "google/cloud"
          #
          #   gcloud = Google::Cloud.new
          #   storage = gcloud.storage
          #
          #   bucket = storage.bucket "my-bucket"
          #   files = bucket.files
          #   files.all(request_limit: 10) do |file|
          #     puts file.name
          #   end
          #
          def all request_limit: nil
            request_limit = request_limit.to_i if request_limit
            unless block_given?
              return enum_for(:all, request_limit: request_limit)
            end
            results = self
            loop do
              results.each { |r| yield r }
              if request_limit
                request_limit -= 1
                break if request_limit < 0
              end
              break unless results.next?
              results = results.next
            end
          end

          ##
          # @private New File::List from a Google API Client
          # Google::Apis::StorageV1::Objects object.
          def self.from_gapi gapi_list, service, bucket = nil, prefix = nil,
                             delimiter = nil, max = nil, versions = nil
            files = new(Array(gapi_list.items).map do |gapi_object|
              File.from_gapi gapi_object, service
            end)
            files.instance_variable_set :@token, gapi_list.next_page_token
            files.instance_variable_set :@prefixes, Array(gapi_list.prefixes)
            files.instance_variable_set :@service, service
            files.instance_variable_set :@bucket, bucket
            files.instance_variable_set :@prefix, prefix
            files.instance_variable_set :@delimiter, delimiter
            files.instance_variable_set :@max, max
            files.instance_variable_set :@versions, versions
            files
          end

          protected

          ##
          # Raise an error unless an active service is available.
          def ensure_service!
            fail "Must have active connection" unless @service
          end
        end
      end
    end
  end
end
