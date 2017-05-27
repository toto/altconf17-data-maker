require 'pp'
require 'date'
require 'time'
require 'csv'
require 'json'

class Speaker 
  attr_reader :name
  attr_reader :bio
  attr_reader :email, :twitter
  attr_reader :avatar_url
  
end

NON_SESSIONS = ["Setup", "Open Doors", "Lunch", "Cleanup", "End of Day", "Break"]

class Session  
  
  
  
  
  attr_reader :speakers
  attr_reader :location
  attr_reader :begin, :end
  attr_reader :title, :abstract
end

class Location
  attr_reader :name
  
  def identifier
    return @name
  end
  
  def initialize(name)
    @name = name
  end
end

# speakers_csv = CSV.new(File.expand_path(ARGV[-2]), {headers: true})
sessions_csv = CSV.new(File.read(File.expand_path(ARGV[-1])), {headers: false})

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



# pp day_per_col
# pp locations_per_col
# pp sessions_per_day_and_location

for key in sessions_per_day_and_location.keys 
  day = key[0]
  date = day.split(",").last
  puts
  puts "# Day #{key[0]}, Room #{key[1]}"
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

    unless NON_SESSIONS.include?(session[:speaker])
      puts "#{session[:speaker]}, #{start_time}, #{duration / 60.0} min"
    end
  end
  
end

