require 'pp'
require 'date'
require 'time'
require 'csv'
require 'json'

class Speaker 
  attr_accessor :name
  attr_accessor :bio
  attr_accessor :email, :twitter
  attr_accessor :avatar_url
  
  def self.from_row(csv_row)
    speaker = Speaker.new
    speaker.name = csv_row["Name"]
    speaker.email = csv_row["Email"]
    speaker.twitter = csv_row["Twitter"]
    speaker.bio = csv_row["Bio"]
    speaker.avatar_url = csv_row["Gravatar"]
    speaker
  end
end

class Session  
  attr_accessor :speakers
  attr_accessor :location
  attr_accessor :begin, :end
  attr_accessor :title, :abstract
  attr_accessor :recording_mp4_url
  attr_accessor :recording_youtube_url
  attr_accessor :slides_url
  
  # in seconds
  def duration
    (@end.to_id - @begin.to_i)
  end
  
  def initialize
    @speakers = []
  end
  
  def update_with_speaker_row(csv_row)
    @abstract = csv_row["Abstract"]
    @title = csv_row["Session Name"]
    @recording_mp4_url = csv_row["Video MP4 URL"]
    @slides_url = csv_row["Slides"]
    self
  end
end


NON_SESSIONS = ["Setup", "Open Doors", "Lunch", "Cleanup", "End of Day", "Break"]

class Location
  attr_accessor :name
end

class Track
  attr_accessor :name
end

sessions_csv = CSV.new(File.read(File.expand_path(ARGV[-1])), {headers: false})


## SORT AND FILTER SCHEDULE

locations_per_col = []
day_per_col = []
session_per_col = []
sessions_per_day_and_location = {}

sessions_csv.each_with_index do |row,index|
  
  if index == 0 # Day
    last_day = nil
    row.each_with_index do |day, index|
      if index > 1 && !day.nil? && day.size > 0
        last_day = day
      end

      day_per_col[index] = last_day
    end
    
  elsif index == 1 # Location
    last_location = nil
    row.each_with_index do |location, index|
      if index > 1 && !location.nil? && location.size > 0
        last_location = location
      end

      locations_per_col[index] = last_location
    end
  elsif !row[0].nil? && row[0] =~ / (AM|PM)/
    time = row[0]
    
    last_sessions = []
    row.each_with_index do |speaker_for_session, index|
      next unless locations_per_col.count > index
      next unless index > 1
      location = locations_per_col[index]
      day = day_per_col[index]

      if !speaker_for_session.nil? && speaker_for_session.size > 0 
        key = [day, location]
        sessions_per_day_and_location[key] ||= []
        sessions_per_day_and_location[key] << { day: day,
                                                time: time,
                                                location: location,
                                                speaker: speaker_for_session }
      end
    end
    
  end
end



## OUTPUT

all_locations = {}
all_sessions = []
all_speakers = []

for key in sessions_per_day_and_location.keys 
  day = key[0]
  date = day.split(",").last
  room = key[1]
  puts
  puts "# Day #{day}, Room #{room}"
  sessions = sessions_per_day_and_location[key]
  sessions.each_with_index do |session, index|
    next if sessions.nil?
    
    next_session = if sessions.count > index 
      sessions[index+1]
    end
    start_time = Time.parse("#{date} 2017 #{session[:time]} PDT") # AltConf is in San Jose so PDT
    end_time = if next_session
      Time.parse("#{date} 2017 #{next_session[:time]} PDT") # AltConf is in San Jose so PDT    
    else
      Time.at(start_time.to_i + 30.0 * 60.0) # default to 30 min sessions
    end
    duration = end_time.to_i - start_time.to_i
    speaker = session[:speaker].strip
    unless NON_SESSIONS.include?(speaker)
      puts "#{speaker}, #{start_time}, #{duration / 60.0} min"
      
      location = all_locations[room]
      location ||= Location.new
      location.name = room
      all_locations[room] = location
      
      
      session = Session.new
      session.speakers = [speaker]
      session.begin = start_time
      session.end = end_time
      session.location = location
      
      all_sessions << session
    end
  end
  
end

## SPEAKERS

speakers_csv = CSV.new(File.read(File.expand_path(ARGV[-2])), {headers: true})

speakers_csv.each do |row|
  speaker = Speaker.from_row(row)
  session = all_sessions.find {|session| session.speakers.include?(speaker.name) }
  
  if session
    session.update_with_speaker_row(row)
    session.speakers = [speaker]

    all_speakers << speaker
  end
  
end

