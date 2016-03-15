class GoogleCalWrapper

  RESOURCE_ID_MAP = {
    "flatironschool.com_36383633393236392d333336@resource.calendar.google.com" => "Classroom - Kay", 
    "flatironschool.com_31373234393535322d343338@resource.calendar.google.com" => "Classroom - Turing",
    "flatironschool.com_31373632383930392d313938@resource.calendar.google.com" => "Classroom - Hopper"
  }

  RESOURCE_IDS = [
    {id: "flatironschool.com_36383633393236392d333336@resource.calendar.google.com"},
    {id: "flatironschool.com_31373234393535322d343338@resource.calendar.google.com"},
    {id: "flatironschool.com_31373632383930392d313938@resource.calendar.google.com"}
  ]

  attr_accessor :client, :service

  def initialize(current_user)
    configure_client(current_user)
  end

  def configure_client(current_user)
    @client = Google::APIClient.new
    @client.authorization.access_token = current_user.token
    @client.authorization.refresh_token = current_user.refresh_token
    @client.authorization.client_id = ENV['GOOGLE_CLIENT_ID']
    @client.authorization.client_secret = ENV['GOOGLE_CLIENT_SECRET']
    @client.authorization.refresh!
    @service = @client.discovered_api('calendar', 'v3')
  end

  def best_available_location(date, activity_start_time, activity_end_time)
    check_available_rooms(date, activity_start_time, activity_end_time)
  end

  def check_available_rooms(date, activity_start_time, activity_end_time)
    response = get_exisiting_reservations(date)
    free_room_id = nil

    response["calendars"].each do |cal_id, data|
      room_conflicts = []
      if !free_room_id
        data.each do |busy, reservations|
          reservations.each do |reservation|
            room_conflicts << conflict?(reservation, activity_start_time, activity_end_time)
          end
          if !room_conflicts.any?
            free_room_id = cal_id
            break
          end
        end
      end
    end

    get_free_room(free_room_id)
  end

  def get_free_room(free_room_id)
    RESOURCE_ID_MAP[free_room_id]
  end
        

  def conflict?(reservation, activity_start_time, activity_end_time)
    if activity_start_time >= (reservation["end"].to_datetime + 1.hours) || activity_end_time <= (reservation["start"].to_datetime + 1.hours)
      return false
    else
      return true
    end
  end

  def build_calendar_events(reservation_activities, date)
    reservation_activities.map do |activity|
      start_time = format_date(date, activity.start_time)
      
      end_time = format_date(date, activity.end_time) 
      available_location = best_available_location(date, start_time, end_time)
      
      {summary: activity.description, 
        location: available_location,
        start: {dateTime: (start_time.to_datetime - 1.hours)},  
        end: {dateTime: (end_time.to_datetime - 1.hours)},  
        description: activity.description,  
      } 
    end
  end

  def format_date(date, activity_time)
    hour = activity_time.hour
    minute = activity_time.to_datetime.minute
    date = date + (hour.hours) + (minute.minutes)
    date.strftime("%Y-%m-%dT%H:%M:%S+%H%M")[0..-6] << "-05:00"
  end

  def get_exisiting_reservations(date)
    start_time = date.strftime("%Y-%m-%dT%H:%M:%S+%H%M")[0..-6] << "-05:00"
    end_time = (date + 23.hours).strftime("%Y-%m-%dT%H:%M:%S+%H%M")[0..-6] << "-05:00"
    
    response = @client.execute(api_method: @service.freebusy.query, 
      body: JSON.dump({timeMin: start_time,
        timeMax: end_time,
        timeZone: "EST",
        items: RESOURCE_IDS}),
      headers: {'Content-Type' => 'application/json'}
    )

    JSON.parse(response.body)
  end


end

