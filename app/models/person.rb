class Person < ActiveRecord::Base
  require "bean"   
  set_table_name "person"
  set_primary_key "person_id"

  include Openmrs

  cattr_accessor :session_datetime
  attr_accessor :education_level, :religion

  has_one :patient, :foreign_key => :patient_id, :dependent => :destroy
  has_one :birth_report, :foreign_key => :person_id, :dependent => :destroy
  has_many :names, :class_name => 'PersonName', :foreign_key => :person_id, :dependent => :destroy, :conditions => 'person_name.voided = 0', :order => 'person_name.preferred DESC'
  has_many :addresses, :class_name => 'PersonAddress', :foreign_key => :person_id, :dependent => :destroy, :conditions => 'person_address.voided = 0', :order => 'person_address.preferred DESC'
  has_many :person_attributes, :foreign_key => :person_id, :dependent => :destroy #, :conditions => 'person.voided = 0'
  has_many :observations, :class_name => 'Observation', :foreign_key => :person_id, :dependent => :destroy, :conditions => 'obs.voided = 0' do

    def find_by_concept_name(name)
      concept_name = ConceptName.find_by_name(name)
      find(:all, :conditions => ['concept_id = ?', concept_name.concept_id]) rescue []
    end
  end
  #  accepts_nested_attributes_for :names, :addresses, :patient

  
  def name
    "#{self.names.first.given_name} #{self.names.first.family_name}" rescue nil
  end  

  def address
    address = self.current_district rescue ""
    if address.blank?
      address = self.current_residence rescue ""
    else
      address += ", " + self.current_residence unless self.current_residence.blank?
    end
    address   
  end 

  def age(today = Date.today)
    return nil if self.birthdate.nil?

    # This code which better accounts for leap years
    patient_age = (today.year - self.birthdate.year) + ((today.month - self.birthdate.month) + ((today.day - self.birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date=self.birthdate
    estimate=self.birthdate_estimated
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  && 
        today.month < birth_date.month && self.date_created.year == today.year) ? 1 : 0
  end

  def age_in_months(today = Date.today)
    years = (today.year - self.birthdate.year)
    months = (today.month - self.birthdate.month)
    (years * 12) + months
  end
    
  def birthdate_formatted
    if self.birthdate_estimated
      if self.birthdate.day == 1 and self.birthdate.month == 7
        self.birthdate.strftime("??/???/%Y")
      elsif self.birthdate.day == 15 
        self.birthdate.strftime("??/%b/%Y")
      end
    else
      self.birthdate.strftime("%d/%b/%Y")
    end
  end

  def set_birthdate(year = nil, month = nil, day = nil)   
    raise "No year passed for estimated birthdate" if year.nil?

    # Handle months by name or number (split this out to a date method)    
    month_i = (month || 0).to_i
    month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
    month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
    
    if month_i == 0 || month == "Unknown"
      self.birthdate = Date.new(year.to_i,7,1)
      self.birthdate_estimated = 1
    elsif day.blank? || day == "Unknown" || day == 0
      self.birthdate = Date.new(year.to_i,month_i,15)
      self.birthdate_estimated = 1
    else
      self.birthdate = Date.new(year.to_i,month_i,day.to_i)
      self.birthdate_estimated = 0
    end
  end

  def set_birthdate_by_age(age, today = Date.today)
    self.birthdate = Date.new(today.year - age.to_i, 7, 1)
    self.birthdate_estimated = 1
  end

  def demographics


    if self.birthdate_estimated
      birth_day = "Unknown"
      if self.birthdate.month == 7 and self.birthdate.day == 1
        birth_month = "Unknown"
      else
        birth_month = self.birthdate.month
      end
    else
      birth_month = self.birthdate.month
      birth_day = self.birthdate.day
    end

    demographics = {"person" => {
        "date_changed" => self.date_changed.to_s,
        "gender" => self.gender,
        "birth_year" => self.birthdate.year,
        "birth_month" => birth_month,
        "birth_day" => birth_day,
        "names" => {
          "given_name" => self.names[0].given_name,
          "family_name" => self.names[0].family_name,
          "family_name2" => ""
        },
        "addresses" => {
          "county_district" => "",
          "city_village" => self.addresses[0].city_village
        },
      }}
 
    if not self.patient.patient_identifiers.blank? 
      demographics["person"]["patient"] = {"identifiers" => {}}
      self.patient.patient_identifiers.each{|identifier|
        demographics["person"]["patient"]["identifiers"][identifier.type.name] = identifier.identifier
      }
    end

    return demographics
  end

 

  def self.search(params)
    people = Person.search_by_identifier(params[:identifier])

    return people.first.id unless people.blank? || people.size > 1
    people = Person.find(:all, :include => [{:names => [:person_name_code]}, :patient], :conditions => [
        "gender = ? AND \
     person.voided = 0 AND \
     (patient.voided = 0 OR patient.voided IS NULL) AND \
     (person_name.given_name LIKE ? OR person_name_code.given_name_code LIKE ?) AND \
     (person_name.family_name LIKE ? OR person_name_code.family_name_code LIKE ?)",
        params[:gender],
        params[:given_name],
        (params[:given_name] || '').soundex,
        params[:family_name],
        (params[:family_name] || '').soundex
      ]) if people.blank?

    return people
    
  end
  def self.search_by_identifier(identifier)
    identifier = identifier.gsub("-","").strip
    found_people = PatientIdentifier.find_all_by_identifier(identifier)
    people = found_people.map{|id| 
      id.patient.person
    } unless found_people.blank? rescue nil
    return people unless people.blank?
    
    create_from_dde_server = CoreService.get_global_property_value('create.from.dde.server').to_s == "true" rescue false
    if create_from_dde_server 
      dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
      dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""
      dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""
      uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json"
      uri += "?value=#{identifier}"                          
      p = JSON.parse(RestClient.get(uri)) rescue nil
      return [] if p.blank?
      return "found duplicate identifiers" if p.count > 1
      p = p.first
      passed_national_id = (p["person"]["patient"]["identifiers"]["National id"]) rescue nil
      passed_national_id = (p["person"]["value"]) if passed_national_id.blank? rescue nil
      if passed_national_id.blank?
        return [DDEService.get_remote_person(p["person"]["id"])]
      end

      birthdate_year = p["person"]["birthdate"].to_date.year rescue "Unknown"
      birthdate_month = p["person"]["birthdate"].to_date.month rescue nil
      birthdate_day = p["person"]["birthdate"].to_date.day rescue nil
      birthdate_estimated = p["person"]["birthdate_estimated"] 
      gender = p["person"]["gender"] == "F" ? "Female" : "Male"

      passed = {
        "person"=>{"occupation"=>p["person"]["data"]["attributes"]["occupation"],
          "age_estimate"=> birthdate_estimated,
          "cell_phone_number"=>p["person"]["data"]["attributes"]["cell_phone_number"],
          "birth_month"=> birthdate_month ,
          "addresses"=>{"address1"=>p["person"]["data"]["addresses"]["address1"],
            "address2"=>p["person"]["data"]["addresses"]["address2"],
            "city_village"=>p["person"]["data"]["addresses"]["city_village"],
            "state_province"=>p["person"]["data"]["addresses"]["state_province"],
            "neighborhood_cell"=>p["person"]["data"]["addresses"]["neighborhood_cell"],
            "county_district"=>p["person"]["data"]["addresses"]["county_district"]},
          "gender"=> gender ,
          "patient"=>{"identifiers"=>{"National id" => p["person"]["value"]}},
          "birth_day"=>birthdate_day,
          "home_phone_number"=>p["person"]["data"]["attributes"]["home_phone_number"],
          "names"=>{"family_name"=>p["person"]["family_name"],
            "given_name"=>p["person"]["given_name"],
            "middle_name"=>""},
          "birth_year"=>birthdate_year},
        "filter_district"=>"",
        "filter"=>{"region"=>"",
          "t_a"=>""},
        "relation"=>""
      }

      unless passed_national_id.blank?                                          
        patient = PatientIdentifier.find(:first,                                
          :conditions =>["voided = 0 AND identifier = ?",passed_national_id]).patient rescue nil
        return [patient.person] unless patient.blank?                           
      end
      
      passed["person"].merge!("identifiers" => {"National id" => passed_national_id})
      created_person = [self.create_from_form(passed["person"])]
      return  created_person
    end
    return people
  end

  def self.find_by_demographics(person_demographics)
    national_id = person_demographics["person"]["patient"]["identifiers"]["National id"] rescue nil
    results = Person.search_by_identifier(national_id) unless national_id.nil?
    return results unless results.blank?

    gender = person_demographics["person"]["gender"] rescue nil
    given_name = person_demographics["person"]["names"]["given_name"] rescue nil
    family_name = person_demographics["person"]["names"]["family_name"] rescue nil

    search_params = {:gender => gender, :given_name => given_name, :family_name => family_name }

    results = Person.search(search_params)

  end

  def self.create_from_form_old(params)
    
    #return rescue text if remote timed out or creation of patient on remote failed
    if params.to_s == 'timeout' || params.to_s == 'creationfailed'
      return params.to_s
    end
    
    if params.has_key?('person')
      params = params['person']
    end

    address_params = params["addresses"]
    names_params = params["names"]
    patient_params = params["patient"]
    person_attribute_params = params["attributes"]

    params_to_process = params.reject{|key,value| key.match(/addresses|patient|names|attributes/) }
    birthday_params = params_to_process.reject{|key,value| key.match(/gender/) }
    person_params = params_to_process.reject{|key,value|
      key.match(/birth_|age_estimate|race|occupation|citizenship|home_phone_number|cell_phone_number/) }

    # raise person_params.to_yaml

    if params.has_key?('person')
      person = Person.create(person_params[:person])
    else
      person = Person.create(person_params)
    end   
    
    if birthday_params["birth_year"] == "Unknown"
      person.set_birthdate_by_age(birthday_params["age_estimate"])
    else
      person.set_birthdate(birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
    end
    person.birthdate_estimated = 1 if params["birthdate_estimated"] == 'true'
    person.save
    person.names.create(names_params)
    person.addresses.create(address_params)

    # add person attributes
    person_attribute_params.each do |attribute_type_name, attribute|
      attribute_type = PersonAttributeType.find_by_name(attribute_type_name.humanize.titleize) || 
        PersonAttributeType.find_by_name("Unknown id")

      person.person_attributes.create("value" => attribute, "person_attribute_type_id" => 
          attribute_type.person_attribute_type_id) unless attribute.blank? rescue nil

    end if person_attribute_params

    # TODO handle the birthplace attribute
 
    if (!patient_params.nil?)
      patient = person.create_patient

      patient_params["identifiers"].each{|identifier_type_name, identifier|
        identifier_type = PatientIdentifierType.find_by_name(identifier_type_name.gsub('_', ' ')) || PatientIdentifierType.find_by_name("Unknown id")
        next if identifier.empty?
        patient.patient_identifiers.create("identifier" => identifier, "identifier_type" => identifier_type.patient_identifier_type_id)
      } if patient_params["identifiers"]


      
      # This might actually be a national id, but currently we wouldn't know
      #patient.patient_identifiers.create("identifier" => patient_params["identifier"], "identifier_type" => PatientIdentifierType.find_by_name("Unknown id")) unless params["identifier"].blank?
    end
    return person
  end

  def self.create_from_form(params)
    #return rescue text if remote timed out or creation of patient on remote failed
    if params.to_s == 'timeout' || params.to_s == 'creationfailed'
      return params.to_s
    end

    if params.has_key?('person')
      params = params['person']
    end
    
    address_params = params["addresses"]
		names_params = params["names"]
		patient_params = params["patient"]
		
		params_to_process = params.reject{|key,value| key.match(/addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy/) }
		
		birthday_params = params_to_process.reject{|key,value| key.match(/gender/) }
		person_params = params_to_process.reject{|key,value| key.match(/birth_|age_estimate|occupation|identifiers|citizenship|race/) }

		if person_params["gender"].to_s == "Female"
      person_params["gender"] = 'F'
		elsif person_params["gender"].to_s == "Male"
      person_params["gender"] = 'M'
		end

    person_params["attributes"].delete("occupation") if person_params["attributes"]
    person_params["attributes"].delete("cell_phone_number") if person_params["attributes"]

    person = Person.create(person_params)

		unless birthday_params.empty?
		  if birthday_params["birth_year"] == "Unknown"
        self.set_birthdate_by_age(person, birthday_params["age_estimate"], person.session_datetime || Date.today)
		  else
        self.set_birthdate(person, birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
		  end
		end
		person.save

		person.names.create(names_params)
		person.addresses.create(address_params) unless address_params.empty? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Occupation").person_attribute_type_id,
		  :value => params["occupation"]) unless params["occupation"].blank? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Cell Phone Number").person_attribute_type_id,
		  :value => params["cell_phone_number"]) unless params["cell_phone_number"].blank? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Office Phone Number").person_attribute_type_id,
		  :value => params["office_phone_number"]) unless params["office_phone_number"].blank? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Home Phone Number").person_attribute_type_id,
		  :value => params["home_phone_number"]) unless params["home_phone_number"].blank? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Citizenship").person_attribute_type_id,
		  :value => params["citizenship"]) unless params["citizenship"].blank? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Race").person_attribute_type_id,
		  :value => params["race"]) unless params["race"].blank? rescue nil

    # TODO handle the birthplace attribute

		if (!patient_params.nil?)
		  patient = person.create_patient

		  patient_params["identifiers"].each{|identifier_type_name, identifier|
        next if identifier.blank?
        identifier_type = PatientIdentifierType.find_by_name(identifier_type_name) || PatientIdentifierType.find_by_name("Unknown id")
        patient.patient_identifiers.create("identifier" => identifier, "identifier_type" => identifier_type.patient_identifier_type_id)
		  } if patient_params["identifiers"]

		  # This might actually be a national id, but currently we wouldn't know
		  #patient.patient_identifiers.create("identifier" => patient_params["identifier"], "identifier_type" => PatientIdentifierType.find_by_name("Unknown id")) unless params["identifier"].blank?
		end

		return person
  end

  def self.set_birthdate_by_age(person, age, today = Date.today)
    person.birthdate = Date.new(today.year - age.to_i, 7, 1)
    person.birthdate_estimated = 1
  end

  def self.set_birthdate(person, year = nil, month = nil, day = nil)
    raise "No year passed for estimated birthdate" if year.nil?

    # Handle months by name or number (split this out to a date method)
    month_i = (month || 0).to_i
    month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
    month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?

    if month_i == 0 || month == "Unknown"
      person.birthdate = Date.new(year.to_i,7,1)
      person.birthdate_estimated = 1
    elsif day.blank? || day == "Unknown" || day == 0
      person.birthdate = Date.new(year.to_i,month_i,15)
      person.birthdate_estimated = 1
    else
      person.birthdate = Date.new(year.to_i,month_i,day.to_i)
      person.birthdate_estimated = 0
    end
  end

  def self.find_remote_by_identifier(identifier)
    known_demographics = {:person => {:patient => { :identifiers => {"National id" => identifier }}}}
    result = Person.find_remote(known_demographics)
  end

  # use the autossh tunnels setup in environment.rb to query the demographics servers
  # then pull down the demographics
  def self.find_remote(known_demographics)
    create_from_remote = CoreService.get_global_property_value("create.from.remote")
	  if create_from_remote
      servers = CoreService.get_global_property_value("remote_servers.parent")
      server_address_and_port = servers.to_s.split(':')

      server_address = server_address_and_port.first
      server_port = server_address_and_port.second

      login = CoreService.get_global_property_value("remote_bart.username").split(/,/) rescue ""
      password = CoreService.get_global_property_value("remote_bart.password").split(/,/) rescue ""
      location = CoreService.get_global_property_value("remote_bart.location").split(/,/) rescue nil
      machine = CoreService.get_global_property_value("remote_machine.account_name").split(/,/) rescue ''

      uri = "http://#{server_address}:#{server_port}/people/remote_demographics"
      
      p = JSON.parse(RestClient.post(uri, known_demographics)).first # rescue nil
      return [] if p.blank?

      results = p.second if p.second and p.first.match /person/

      results["occupation"] = results["attributes"]["occupation"]
      results["cell_phone_number"] = results["attributes"]["cell_phone_number"]
      results["home_phone_number"] =  results["attributes"]["home_phone_number"]
      results["office_phone_number"] = results["attributes"]["office_phone_number"]
      results["attributes"].delete("occupation")
      results["attributes"].delete("cell_phone_number")
      results["attributes"].delete("home_phone_number")
      results["attributes"].delete("office_phone_number")

      return [self.create_from_form(results)]
    end
  end
  
  def formatted_gender

    if self.gender == "F" then "Female"
    elsif self.gender == "M" then "Male"
    else "Unknown"
    end
    
  end

  def self.create_remote(received_params)
    new_params = received_params[:person]
    known_demographics = Hash.new()
    new_params['gender'] == 'F' ? new_params['gender'] = "Female" : new_params['gender'] = "Male"

    known_demographics = {
      "occupation"=>"#{new_params[:attributes][:occupation]}",
      "education_level"=>"#{new_params[:attributes][:education_level]}",
      "religion"=>"#{new_params[:attributes][:religion]}",
      "patient_year"=>"#{new_params[:birth_year]}",
      "patient"=>{
        "gender"=>"#{new_params[:gender]}",
        "birthplace"=>"#{new_params[:addresses][:address2]}",
        "creator" => 1,
        "changed_by" => 1
      },
      "p_address"=>{
        "identifier"=>"#{new_params[:addresses][:state_province]}"},
      "home_phone"=>{
        "identifier"=>"#{new_params[:attributes][:home_phone_number]}"},
      "cell_phone"=>{
        "identifier"=>"#{new_params[:attributes][:cell_phone_number]}"},
      "office_phone"=>{
        "identifier"=>"#{new_params[:attributes][:office_phone_number]}"},
      "patient_id"=>"",
      "patient_day"=>"#{new_params[:birth_day]}",
      "patientaddress"=>{"city_village"=>"#{new_params[:addresses][:city_village]}"},
      "patient_name"=>{
        "family_name"=>"#{new_params[:names][:family_name]}",
        "given_name"=>"#{new_params[:names][:given_name]}", "creator" => 1
      },
      "patient_month"=>"#{new_params[:birth_month]}",
      "patient_age"=>{
        "age_estimate"=>"#{new_params[:age_estimate]}"
      },
      "age"=>{
        "identifier"=>""
      },
      "current_ta"=>{
        "identifier"=>"#{new_params[:addresses][:county_district]}"}
    }

    demographics_params = CGI.unescape(known_demographics.to_param).split('&').map{|elem| elem.split('=')}
    
    mechanize_browser = WWW::Mechanize.new

    demographic_servers = JSON.parse(GlobalProperty.find_by_property("demographic_server_ips_and_local_port").property_value) rescue []

    result = demographic_servers.map{|demographic_server, local_port|

      begin

        output = mechanize_browser.post("http://#{demographic_server}:#{local_port}/patient/create_remote", demographics_params).body

      rescue Timeout::Error 
        return 'timeout'
      rescue
        return 'creationfailed'
      end

      output if output and output.match(/person/)

    }.sort{|a,b|b.length <=> a.length}.first

    result ? JSON.parse(result) : nil
  end

  def phone_numbers
    phone_numbers = {}
    ["Cell Phone Number","Home Phone Number","Office Phone Number"].each{|attribute_type_name|
      number = PersonAttribute.find(:first,:conditions => ["voided = 0 AND person_attribute_type_id = ? AND person_id = ?", PersonAttributeType.find_by_name("#{attribute_type_name}").id, self.id]).value rescue ""
      phone_numbers[attribute_type_name] = number 
    }
    phone_numbers
    phone_numbers.delete_if {|key, value| value == "" }
  end

  def occupation
    occupation = PersonAttribute.find(:first,:conditions => ["voided = 0 AND person_attribute_type_id = ? AND person_id = ?", PersonAttributeType.find_by_name('Occupation').id, self.id]).value rescue 'Uknown'
  end

  def self.update_demographics(params)
    person = Person.find(params['person_id'])
    
    if params.has_key?('person')
      params = params['person']
    end
    
    address_params = params["addresses"]
    names_params = params["names"]
    patient_params = params["patient"]
    person_attribute_params = params["attributes"]

    params_to_process = params.reject{|key,value| key.match(/addresses|patient|names|attributes/) }
    birthday_params = params_to_process.reject{|key,value| key.match(/gender/) }

    person_params = params_to_process.reject{|key,value| key.match(/birth_|age_estimate/) }
   
    if !birthday_params.empty?
      
      if birthday_params["birth_year"] == "Unknown"
        person.set_birthdate_by_age(birthday_params["age_estimate"])
      else
        person.set_birthdate(birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
      end
      
      person.birthdate_estimated = 1 if params["birthdate_estimated"] == 'true'
      person.save
    end
    
    person.update_attributes(person_params) if !person_params.empty?
    person.names.first.update_attributes(names_params) if names_params
    person.addresses.first.update_attributes(address_params) if address_params

    #update or add new person attribute
    person_attribute_params.each{|attribute_type_name, attribute|
      attribute_type = PersonAttributeType.find_by_name(attribute_type_name.humanize.titleize) || PersonAttributeType.find_by_name("Unknown id")
      #find if attribute already exists
      exists_person_attribute = PersonAttribute.find(:first, :conditions => ["person_id = ? AND person_attribute_type_id = ?", person.id, attribute_type.person_attribute_type_id]) rescue nil
      if exists_person_attribute
        exists_person_attribute.update_attributes({'value' => attribute})
      else
        person.person_attributes.create("value" => attribute, "person_attribute_type_id" => attribute_type.person_attribute_type_id)
      end
    } if person_attribute_params

  end
  
  # Person's short name to fit on small labels
  def short_name
    "#{self.names.first.given_name.first}. #{self.names.first.family_name}" rescue nil
  end

  def current_residence
    #current_residence = PersonAttribute.find(:first,:conditions => ["voided = 0 AND person_attribute_type_id = ? AND person_id = ?",
    #    PersonAttributeType.find_by_name('Current Place Of Residence').id, self.id]).value rescue 'Unknown'

    self.addresses.last.city_village rescue 'Unknown'
  end

  def current_district
    "#{self.addresses.last.state_province}" rescue nil
  end

  def sex
    if self.gender == "M"
      return "Male"
    elsif self.gender == "F"
      return "Female"
    else
      return nil
    end
  end
  
  def self.search_from_remote(params)
    return [] if params[:given_name].blank?
    dde_server = CoreService.get_global_property_value("dde_server_ip") rescue nil
    dde_server_username = CoreService.get_global_property_value("dde_server_username") rescue ""
    dde_server_password = CoreService.get_global_property_value("dde_server_password") rescue ""
    uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json/"

    return JSON.parse(RestClient.post(uri,params))
  end
  def self.sex(person)
    value = nil
    if person.gender == "M"
      value = "Male"
    elsif person.gender == "F"
      value = "Female"
    end
    value
  end
  def self.age(person, today = Date.today)
    return nil if person.birthdate.nil?

    # This code which better accounts for leap years
    patient_age = (today.year - person.birthdate.year) + ((today.month - person.birthdate.month) + ((today.day - person.birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date=person.birthdate
    estimate=person.birthdate_estimated==1
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && person.date_created.year == today.year) ? 1 : 0
  end
  def self.age_in_months(person, today = Date.today)
    years = (today.year - person.birthdate.year)
    months = (today.month - person.birthdate.month)
    (years * 12) + months
  end
  def self.birthdate_formatted(person)
    if person.birthdate_estimated==1
      if person.birthdate.day == 1 and person.birthdate.month == 7
        person.birthdate.strftime("??/???/%Y")
      elsif person.birthdate.day == 15
        person.birthdate.strftime("??/%b/%Y")
      elsif person.birthdate.day == 1 and person.birthdate.month == 1
        person.birthdate.strftime("??/???/%Y")
      end
    else
      person.birthdate.strftime("%d/%b/%Y")
    end
  end
  def self.get_attribute(person, attribute)
    PersonAttribute.find(:first,:conditions =>["voided = 0 AND person_attribute_type_id = ? AND person_id = ?",
        PersonAttributeType.find_by_name(attribute).id, person.id]).value rescue nil
  end

  def self.demographics(person_obj)

    if person_obj.birthdate_estimated==1
      birth_day = "Unknown"
      if person_obj.birthdate.month == 7 and person_obj.birthdate.day == 1
        birth_month = "Unknown"
      else
        birth_month = person_obj.birthdate.month
      end
    else
      birth_month = person_obj.birthdate.month
      birth_day = person_obj.birthdate.day
    end

    demographics = {"person" => {
        "date_changed" => person_obj.date_changed.to_s,
        "gender" => person_obj.gender,
        "birth_year" => person_obj.birthdate.year,
        "birth_month" => birth_month,
        "birth_day" => birth_day,
        "names" => {
          "given_name" => person_obj.names[0].given_name,
          "family_name" => person_obj.names[0].family_name,
          "family_name2" => person_obj.names[0].family_name2
        },
        "addresses" => {
          "county_district" => person_obj.addresses[0].county_district,
          "city_village" => person_obj.addresses[0].city_village,
          "address1" => person_obj.addresses[0].address1,
          "address2" => person_obj.addresses[0].address2
        },
        "attributes" => {"occupation" => self.get_attribute(person_obj, 'Occupation'),
          "cell_phone_number" => self.get_attribute(person_obj, 'Cell Phone Number')}}}
 
    if not person_obj.patient.patient_identifiers.blank? 
      demographics["person"]["patient"] = {"identifiers" => {}}
      person_obj.patient.patient_identifiers.each{|identifier|
        demographics["person"]["patient"]["identifiers"][identifier.type.name] = identifier.identifier
      }
    end

    return demographics
  end

  def self.create_from_dde_server_only(params)
    address_params = params["person"]["addresses"]
    names_params = params["person"]["names"]
    patient_params = params["person"]["patient"]
    birthday_params = params["person"]
    params_to_process = params.reject{|key,value|
      key.match(/identifiers|addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy/)
    }
    birthday_params = params_to_process["person"].reject{|key,value| key.match(/gender/) }
    person_params = params_to_process["person"].reject{|key,value| key.match(/birth_|age_estimate|occupation/) }


    if person_params["gender"].to_s == "Female"
      person_params["gender"] = 'F'
    elsif person_params["gender"].to_s == "Male"
      person_params["gender"] = 'M'
    end

    unless birthday_params.empty?
      if birthday_params["birth_year"] == "Unknown"
        birthdate = Date.new(Date.today.year - birthday_params["age_estimate"].to_i, 7, 1)
        birthdate_estimated = 1
      else
        year = birthday_params["birth_year"]
        month = birthday_params["birth_month"]
        day = birthday_params["birth_day"]

        month_i = (month || 0).to_i
        month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
        month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?

        if month_i == 0 || month == "Unknown"
          birthdate = Date.new(year.to_i,7,1)
          birthdate_estimated = 1
        elsif day.blank? || day == "Unknown" || day == 0
          birthdate = Date.new(year.to_i,month_i,15)
          birthdate_estimated = 1
        else
          birthdate = Date.new(year.to_i,month_i,day.to_i)
          birthdate_estimated = 0
        end
      end
    else
      birthdate_estimated = 0
    end


    passed_params = {"person"=>
        {"data" =>
          {"addresses"=>
            {"state_province"=> address_params["state_province"],
            "address2"=> address_params["address2"],
            "address1"=> address_params["address1"],
            "neighborhood_cell"=> address_params["neighborhood_cell"],
            "city_village"=> address_params["city_village"],
            "county_district"=> address_params["county_district"]
          },
          "attributes"=>
            {"occupation"=> params["person"]["occupation"],
            "cell_phone_number" => params["person"]["cell_phone_number"] },
          "patient"=>
            {"identifiers"=>
              {"diabetes_number"=>""}},
          "gender"=> person_params["gender"],
          "birthdate"=> birthdate,
          "birthdate_estimated"=> birthdate_estimated ,
          "names"=>{"family_name"=> names_params["family_name"],
            "given_name"=> names_params["given_name"]
          }}}}

    @dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
    @dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""
    @dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""

    uri = "http://#{@dde_server_username}:#{@dde_server_password}@#{@dde_server}/people.json/"
    received_params = RestClient.post(uri,passed_params)

    return JSON.parse(received_params)["npid"]["value"]
  end

  def self.create_patient_from_dde(params)
    old_identifier = params["identifier"] rescue nil
	  address_params = params["person"]["addresses"]
		names_params = params["person"]["names"]
		patient_params = params["person"]["patient"]
    birthday_params = params["person"]
		params_to_process = params.reject{|key,value| 
      key.match(/identifiers|addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy/) 
    }
		birthday_params = params_to_process["person"].reject{|key,value| key.match(/gender/) }
		person_params = params_to_process["person"].reject{|key,value| key.match(/birth_|age_estimate|occupation/) }


		if person_params["gender"].to_s == "Female"
      person_params["gender"] = 'F'
		elsif person_params["gender"].to_s == "Male"
      person_params["gender"] = 'M'
		end
    
		unless birthday_params.empty?
		  if birthday_params["birth_year"] == "Unknown"
			  birthdate = Date.new(Date.today.year - birthday_params["age_estimate"].to_i, 7, 1) 
        birthdate_estimated = 1
		  else
			  year = birthday_params["birth_year"]
        month = birthday_params["birth_month"]
        day = birthday_params["birth_day"]

        month_i = (month || 0).to_i                                                 
        month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?   
        month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
                                                                                    
        if month_i == 0 || month == "Unknown"                                       
          birthdate = Date.new(year.to_i,7,1)                                
          birthdate_estimated = 1
        elsif day.blank? || day == "Unknown" || day == 0                            
          birthdate = Date.new(year.to_i,month_i,15)                         
          birthdate_estimated = 1
        else                                                                        
          birthdate = Date.new(year.to_i,month_i,day.to_i)                   
          birthdate_estimated = 0
        end
		  end
    else
      birthdate_estimated = 0
		end

    passed_params = {"person"=> 
        {"data" => 
          {"addresses"=> 
            {"state_province"=> address_params["state_province"],
            "address2"=> address_params["address2"],
            "address1"=> address_params["address1"],
            "neighborhood_cell"=> address_params["neighborhood_cell"],
            "city_village"=> address_params["city_village"],
            "county_district"=> address_params["county_district"]
          }, 
          "attributes"=> 
            {"occupation"=> params["person"]["occupation"], 
            "cell_phone_number" => params["person"]["cell_phone_number"] },
          "patient"=> 
            {"identifiers"=> {"old_identification_number"=> old_identifier}},
          "gender"=> person_params["gender"], 
          "birthdate"=> birthdate, 
          "birthdate_estimated"=> birthdate_estimated , 
          "names"=>{"family_name"=> names_params["family_name"], 
            "given_name"=> names_params["given_name"]
          }}}}

    if !params["remote"]
      
      @dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
    
      @dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""
    
      @dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""
    
      uri = "http://#{@dde_server_username}:#{@dde_server_password}@#{@dde_server}/people.json/"                          
      recieved_params = RestClient.post(uri,passed_params)      
                                          
      national_id = JSON.parse(recieved_params)["npid"]["value"]
    else
      national_id = params["person"]["patient"]["identifiers"]["National_id"]
    end
      
	  person = person = self.create_from_form(params[:person] || params["person"])
    
    identifier_type = PatientIdentifierType.find_by_name("National id") || PatientIdentifierType.find_by_name("Unknown id")
    person.patient.patient_identifiers.create("identifier" => national_id, 
      "identifier_type" => identifier_type.patient_identifier_type_id) unless national_id.blank?
    return person
  end

  def self.get_patient(person)
    require "bean"
    patient = PatientBean.new('')
    patient.person_id = person.id
    patient.patient_id = person.patient.id
    patient.arv_number = get_patient_identifier(person.patient, 'ARV Number')
    patient.address = person.addresses.first.city_village
    patient.national_id = get_patient_identifier(person.patient, 'National id')
	  patient.national_id_with_dashes = get_national_id_with_dashes(person.patient)
    patient.name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
		patient.first_name = person.names.first.given_name rescue nil
		patient.last_name = person.names.first.family_name rescue nil
    patient.sex = sex(person)
    patient.age = age(person, current_date) #rescue nil
    patient.age_in_months = age_in_months(person, current_date) rescue nil
    patient.dead = person.dead
    patient.birth_date = birthdate_formatted(person)
    patient.birthdate_estimated = person.birthdate_estimated
    patient.current_district = person.addresses.first.state_province
    patient.home_district = person.addresses.first.address2
    patient.traditional_authority = person.addresses.first.county_district
    patient.current_residence = person.addresses.first.city_village
    patient.landmark = person.addresses.first.address1
    patient.home_village = person.addresses.first.neighborhood_cell
    patient.mothers_surname = person.names.first.family_name2
    patient.eid_number = get_patient_identifier(person.patient, 'EID Number') rescue nil
    patient.pre_art_number = get_patient_identifier(person.patient, 'Pre ART Number (Old format)') rescue nil
    patient.archived_filing_number = get_patient_identifier(person.patient, 'Archived filing number')rescue nil
    patient.filing_number = get_patient_identifier(person.patient, 'Filing Number')
    patient.occupation = get_attribute(person, 'Occupation')
    patient.cell_phone_number = get_attribute(person, 'Cell phone number')
    patient.office_phone_number = get_attribute(person, 'Office phone number')
    patient.home_phone_number = get_attribute(person, 'Home phone number')
    patient.guardian = art_guardian(person.patient) rescue nil
    patient
  end

  def self.get_dde_person(person, current_date = Date.today)
    patient = PatientBean.new('')
    patient.person_id = person["person"]["id"]
    patient.patient_id = 0
    patient.address = person["person"]["addresses"]["city_village"]
    patient.national_id = person["person"]["patient"]["identifiers"]["National id"]
    patient.name = person["person"]["names"]["given_name"] + ' ' + person["person"]["names"]["family_name"] rescue nil
    patient.first_name = person["person"]["names"]["given_name"] rescue nil
    patient.last_name = person["person"]["names"]["family_name"] rescue nil
    patient.sex = person["person"]["gender"]
    patient.birthdate = person["person"]["birthdate"].to_date
    patient.birthdate_estimated =  person["person"]["age_estimate"].to_i rescue 0
    date_created =  person["person"]["date_created"].to_date rescue Date.today
    patient.age = self.cul_age(patient.birthdate , patient.birthdate_estimated , date_created, Date.today)
    patient.birth_date = self.get_birthdate_formatted(patient.birthdate,patient.birthdate_estimated)
    patient.home_district = person["person"]["addresses"]["address2"]
    patient.current_district = person["person"]["addresses"]["state_province"]
    patient.traditional_authority = person["person"]["addresses"]["county_district"]
    patient.current_residence = person["person"]["addresses"]["city_village"]
    patient.landmark = person["person"]["addresses"]["address1"]
    patient.home_village = person["person"]["addresses"]["neighborhood_cell"]
    patient.occupation = person["person"]["occupation"]
    patient.cell_phone_number = person["person"]["cell_phone_number"]
    patient.home_phone_number = person["person"]["home_phone_number"]
    patient.old_identification_number = person["person"]["patient"]["identifiers"]["Old national id"]
    patient.national_id  = patient.old_identification_number if patient.national_id.blank?
    patient
  end

  def self.patient_national_id_label(patient)
	  patient_bean = get_patient(patient.person)
    return unless patient_bean.national_id
    sex =  patient_bean.sex.match(/F/i) ? "(F)" : "(M)"
    address = ""
    if !patient_bean.state_province.blank? and !patient_bean.current_residence.blank?
      address = patient_bean.state_province + ", " + patient_bean.current_residence
    elsif !patient_bean.state_province.blank? and patient_bean.current_residence.blank?
      address = patient_bean.state_province
    elsif patient_bean.state_province.blank? and !patient_bean.current_residence.blank?
      address = patient_bean.current_residence
    end

    address = patient_bean.state_province + "," rescue ""
    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50,180,0,1,5,15,120,false,"#{patient_bean.national_id}")
    label.draw_multi_text("#{patient_bean.name.titleize}")
    label.draw_multi_text("#{patient_bean.national_id_with_dashes} #{patient_bean.birth_date}#{sex}")
    label.draw_multi_text("#{address}") unless address.blank?
    label.print(1)
  end

  def self.cul_age(birthdate , birthdate_estimated , date_created = Date.today, today = Date.today)
                                                                                
    # This code which better accounts for leap years                            
    patient_age = (today.year - birthdate.year) + ((today.month - birthdate.month) + ((today.day - birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)
                                                                                
    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date = birthdate                                                      
    estimate = birthdate_estimated == 1                                         
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && date_created.year == today.year) ? 1 : 0
  end

  def self.get_birthdate_formatted(birthdate,birthdate_estimated)
    if birthdate_estimated == 1                                                 
      if birthdate.day == 1 and birthdate.month == 7                            
        birthdate.strftime("??/???/%Y")                                         
      elsif birthdate.day == 15                                                 
        birthdate.strftime("??/%b/%Y")                                          
      elsif birthdate.day == 1 and birthdate.month == 1                         
        birthdate.strftime("??/???/%Y")                                         
      end                                                                       
    else                                                                        
      birthdate.strftime("%d/%b/%Y")                                            
    end                                                                         
  end 

  def self.search_from_dde_by_identifier(identifier)
    dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
    dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""
    dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""
    uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json"
    uri += "?value=#{identifier}"
    people = JSON.parse(RestClient.get(uri)) rescue nil

    return [] if people.blank?

    local_people = []
    people.each do |person|
      national_id = person['person']["value"] rescue nil
      old_national_id = person["person"]["old_identification_number"] rescue nil

      birthdate_year = person["person"]["data"]["birthdate"].to_date.year rescue "Unknown"
      birthdate_month = person["person"]["data"]["birthdate"].to_date.month rescue nil
      birthdate_day = person["person"]["data"]["birthdate"].to_date.day rescue nil
      birthdate_estimated = person["person"]["data"]["birthdate_estimated"]
      gender = person["person"]["data"]["gender"] == "F" ? "Female" : "Male"
      passed_person = {
        "person"=>{"occupation"=>person["person"]["data"]["attributes"]["occupation"],
          "age_estimate"=> birthdate_estimated ,
          "birthdate" => person["person"]["data"]["birthdate"],
          "cell_phone_number"=>person["person"]["data"]["attributes"]["cell_phone_number"],
          "birth_month"=> birthdate_month ,
          "addresses"=>{"address1"=>person["person"]["data"]["addresses"]["address1"],
            "address2"=>person["person"]["data"]["addresses"]["address2"],
            "city_village"=>person["person"]["data"]["addresses"]["city_village"],
            "state_province"=>person["person"]["data"]["addresses"]["state_province"],
            "neighborhood_cell"=>person["person"]["data"]["addresses"]["neighborhood_cell"],
            "county_district"=>person["person"]["data"]["addresses"]["county_district"]},
          "gender"=> gender ,
          "patient"=>{"identifiers"=>{"National id" => national_id ,"Old national id" => old_national_id}},
          "birth_day"=>birthdate_day,
          "home_phone_number"=>person["person"]["data"]["attributes"]["home_phone_number"],
          "names"=>{"family_name"=>person["person"]["data"]["names"]["family_name"],
            "given_name"=>person["person"]["data"]["names"]["given_name"],
            "middle_name"=>""},
          "birth_year"=>birthdate_year,
          "id" => person["person"]["id"]},
        "filter_district"=>"",
        "filter"=>{"region"=>"",
          "t_a"=>""},
        "relation"=>""
      }
      local_people << passed_person
    end
    return local_people
  end

  def self.art_guardian(patient)
    person_id = Relationship.find(:first,:order => "date_created DESC",
      :conditions =>["person_a = ?",patient.person.id]).person_b rescue nil
    guardian_name = name(Person.find(person_id))
    guardian_name rescue nil
  end
  def self.get_patient_identifier(patient, identifier_type)
    patient_identifier_type_id = PatientIdentifierType.find_by_name(identifier_type).patient_identifier_type_id rescue nil
    patient_identifier = PatientIdentifier.find(:first, :select => "identifier",
      :conditions  =>["patient_id = ? and identifier_type = ?", patient.id, patient_identifier_type_id],
      :order => "date_created DESC" ).identifier rescue nil
    return patient_identifier
  end

  def self.person_search(params)
    people = []
    people = search_by_identifier(params[:identifier]) if params[:identifier]

    #return people.first.id unless people.blank? || people.size > 1
    return people unless people.blank? || people.size > 1

    gender = params[:gender]
    given_name = params[:given_name].squish unless params[:given_name].blank?
    family_name = params[:family_name].squish unless params[:family_name].blank?

    people = Person.find(:all, :include => [{:names => [:person_name_code]}, :patient], :conditions => [
        "gender = ? AND \
     person_name.given_name = ? AND \
     person_name.family_name = ?",
        gender,
        given_name,
        family_name
      ]) rescue nil if people.blank?

    if people && people.length < 15
      matching_people = people.collect{| person |
        person.person_id
      }
      # raise matching_people.to_yaml
      people_like = Person.find(:all, :limit => 15, :include => [{:names => [:person_name_code]}, :patient], :conditions => [
          "gender = ? AND \
     person_name_code.given_name_code LIKE ? AND \
     person_name_code.family_name_code LIKE ? AND person.person_id NOT IN (?)",
          gender,
          (given_name || '').soundex,
          (family_name || '').soundex,
          matching_people
        ], :order => "person_name.given_name ASC, person_name_code.family_name_code ASC") rescue nil
      people = people + people_like rescue nil
    end
    return people
  end

  def self.get_national_id_with_dashes(patient, force = true)
    id = self.get_national_id(patient, force)
    length = id.length
    case length
    when 13
      id[0..4] + "-" + id[5..8] + "-" + id[9..-1] rescue id
    when 9
      id[0..2] + "-" + id[3..6] + "-" + id[7..-1] rescue id
    when 6
      id[0..2] + "-" + id[3..-1] rescue id
    else
      id
    end
  end

  def self.get_national_id(patient, force = true)

    id = patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
	
    return id unless force
    id ||= PatientIdentifierType.find_by_name("National id").next_identifier(:patient => patient).identifier
    id
  end

	def mother
		Relationship.find(:last, 
			:order => ["date_created"], 
			:conditions => ["person_b = ? AND relationship = ?", 
        self.person_id, RelationshipType.find(:last, :conditions => ["a_is_to_b = ? AND b_is_to_a = ?", "Mother", "Child"]).id])
	end

end
