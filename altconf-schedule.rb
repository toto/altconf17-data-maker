require 'pp'
require 'date'
require 'time'
require 'csv'
require 'json'
require 'digest'

class Speaker 
  attr_accessor :name, :organization
  attr_accessor :bio
  attr_accessor :email, :twitter
  attr_accessor :avatar_url
  attr_accessor :sessions
  
  def self.from_row(csv_row)
    speaker = Speaker.new
    speaker.name = csv_row["Name"]
    speaker.email = csv_row["Email"]
    speaker.twitter = csv_row["Twitter"]
    speaker.bio = csv_row["Bio"]
    speaker.avatar_url = csv_row["Gravatar"]
    speaker.organization = csv_row["Company"]
    speaker
  end
  
  def initialize
    @sessions = []
  end
  
  def identifier
    Digest::SHA1.hexdigest(name) 
  end
  
  def to_s
    name
  end
  
  def to_h(minimal=false)
    if minimal
      return {
        id: identifier,
        name: name,
      }
    end
    
    {
      id: identifier,
      name: name,
      photo: avatar_url,
      url: "http://altconf.com/17/speakers/#{identifier}",
      organization: organization,
      position: nil,
      biography: bio,
      sessions: sessions.map {|s| s.to_h(true) },
      links: []
     }
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
    (@end.to_i - @begin.to_i)
  end
  
  def initialize
    @speakers = []
  end
  
  def update_with_speaker_row(csv_row)
    @abstract = csv_row["Abstract"]
    if csv_row["Session Name"] && !csv_row["Session Name"].empty? 
      @title = csv_row["Session Name"]
    end
    @recording_mp4_url = csv_row["Video MP4 URL"]
    @slides_url = csv_row["Slides"]
    self
  end
  
  def identifier

    speaker_ids = speakers.sort { |a,b| a.to_s <=> b.to_s }.join("-")
    speaker_ids = self.begin.to_s if speakers.empty?
    Digest::SHA1.hexdigest(speaker_ids)
  end
  
  def to_h(minimal=false)
    if minimal
      return {
                id: identifier,
                title: title
             }
    end
    
    {
      id: identifier,
      title: title,
      subtitle: nil,
      abstract: abstract,
      description: nil,
      url: "https://altconf.com/17/sessions/#{identifier}",
      begin: self.begin.iso8601,
      end: self.end.iso8601,
      duration: duration / 60.0, # in minutes
      day: day,
      location: location.to_h,
      track: track.to_h,
      lang: lang,
      level: level,
      speakers: speakers.map { |s| s.to_h(true) }
    }
  end
  
  def lang
    {
      id: "en",
      label_de: "Englisch",
      label_en: "English"
    }
  end
  
  def format
    {
      id: "talk",
      label_de: "Vortrag",
      label_en: "Talk"
    }
  end
  
  def level
    {
      id: "advanced",
      label_de: "Fortgeschritten",
      label_de: "Advanced",
    }
  end
  
  def track
    Track.altconf
  end
  
  def day
    daystamp = self.begin.strftime("%Y-%m-%d")
    {
      id: daystamp,
      date: daystamp,
      label_de: self.begin.strftime("%A"),
      label_en: self.begin.strftime("%A"),
      type: "day"
   }
  end
  
  # TODO: Add MP4 url
  def enclosures
    return [] if recording_mp4_url.nil?
    
    [{
    	url: recording_mp4_url,
    	mimetype: "video/mp4",
    	type: "recording"
    }]
  end
  
  def links
    return [] if slides_url.nil?
    
    [
      {
        title: "Slides: #{title}",
        url: slides_url,
        type: "slides"
      }
    ]
  end
end


NON_SESSIONS = ["Setup", "Open Doors", "Lunch", "Cleanup", "End of Day", "Break", "OPEN"]

class Location
  attr_accessor :name
  
  def to_h
    {id: name.downcase.gsub(/ /, "-"),
     label_en: name,
     label_de: name}
  end
end

class Track
  attr_accessor :name, :color
  
  def initialize(name, color)
    @name = name
    @color = color
  end
  
  def self.altconf
    @altconf ||= Track.new("AltConf", [0.082, 0.678, 0.239])
  end
  
  def identifier
    @name.downcase
  end
  
  def to_h
    {
      id: identifier,
      label_de: name,
      label_en: name,     
      color: color
    }
  end
end

if ARGV.count != 2
  puts "usage: ruby #{__FILE__} speakers.csv sessions.csv"
  exit(0)
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
    speakers = session[:speaker].strip.split("&").map{|s| s.strip}
    unless NON_SESSIONS.include?(speakers.first)
      puts "#{speakers.join(",")}, #{start_time}, #{duration / 60.0} min"
      
      location = all_locations[room]
      location ||= Location.new
      location.name = room
      all_locations[room] = location
      
      
      session = Session.new
      session.speakers = speakers
      session.begin = start_time
      session.end = end_time
      session.location = location
      session.title = speakers.join(",")
      
      all_sessions << session
    end
  end
  
end

## SPEAKERS

speakers_csv = CSV.new(File.read(File.expand_path(ARGV[-2])), {headers: true})

speakers_csv.each do |row|
  speaker = Speaker.from_row(row)
  session = all_sessions.find {|session| session.speakers.include?(speaker.name) }
  
  speaker.sessions = [session]
  
  if session
    session.update_with_speaker_row(row)
    session.speakers = [speaker]

    all_speakers << speaker
  end
  
end

all_sessions.each do |session|
  speakers = all_speakers.select {|speaker| session.speakers.map {|ss| ss.to_s}.include?(speaker.name) }
  if speakers && !speakers.empty?
    session.speakers = speakers
  else
    session.speakers = []
    # pp session
  end
end

result = {}

result["speakers"] = all_speakers.reject{|s| s.name == nil }.map {|s| s.to_h }
result["sessions"] = all_sessions.reject {|s| s.title == nil }.map {|s| s.to_h }
result["tracks"] = [Track.altconf.to_h]
result["locations"] = all_locations.values.map {|l| l.to_h }

File.open("altconf17.json", "w+") do |f|
  JSON.dump(result, f)
end

