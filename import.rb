# coding: utf-8

# Require support code, used by all the examples.
require 'launchy'
require 'bundler'
Bundler.setup
require 'hallon'
require './rdio'
require './credentials'


rdio = Rdio.new([RDIO_KEY, RDIO_SECRET])
hallon_appkey   = IO.read(File.expand_path('./spotify_appkey.key'))


#
# Log in to spotify
#
session = Hallon::Session.initialize(hallon_appkey) do
  on(:log_message) do |message|
    #puts "[LOG] #{message}"
  end

  on(:credentials_blob_updated) do |blob|
    #puts "[BLOB] #{blob}"
  end

  on(:connection_error) do |error|
    Hallon::Error.maybe_raise(error)
  end

  on(:logged_out) do
    abort "[FAIL] Logged out!"
  end
end
session.login!(HALLON_USERNAME, HALLON_PASSWORD)
session = Hallon::Session.instance
spotify = Hallon::User.new(HALLON_USERNAME)

puts "Successfully logged in to Spotify! Launching rd.io authentication..."


#
# OAuth login via PIN
#
url = rdio.begin_authentication('oob')
Launchy.open(url)
print 'Enter the code: '
verifier = gets.strip
rdio.complete_authentication(verifier)


#
# Get playlists and load
#
puts "Fetching published playlists"
published = spotify.published.load

playlist_count = published.size
copied_to_rdio_count = 0

puts "Loading #{playlist_count} playlists."
all_playlists = published.contents.find_all

all_playlists.each(&:load)


#
# Iterate through playlists of the form "artist - album"
#
all_playlists.each do |playlist|
  parts = playlist.name.split(' – ')
  album = parts.last
  artist = parts.first

  # Ignore playlists not of the default format
  if parts.length == 2
    puts "Spotify playlist: #{album} by #{artist}"
    result = rdio.call('search', {:query => playlist.name, :types => "album"})

    if result["result"]["number_results"] > 0
      rdio_result = result["result"]["results"].first
      rdio_album = rdio_result["name"]
      rdio_artist = rdio_result["artist"]

      puts "Found rd.io match: #{rdio_album} by #{rdio_artist}"

      tracks = rdio_result["trackKeys"].join(",")

      # Add all of the tracks from the result to the user's collection
      response = rdio.call('addToCollection', {:keys => tracks})

      if response["result"] == true
        copied_to_rdio_count = copied_to_rdio_count + 1
      else
        puts response
      end
    else
      puts "!!No match found on rd.io!!"
    end
  end
end

puts "Imported #{copied_to_rdio_count} to rdio out of #{playlist_count} spotify playlists"