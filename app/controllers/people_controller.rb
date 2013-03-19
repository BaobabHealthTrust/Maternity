class PeopleController < ApplicationController
  
  def index
    user =  User.find(session[:user_id])
    @password_expired = false

    password_expiry_date = UserProperty.find_by_property_and_user_id('password_expiry_date', user.user_id).property_value.to_date rescue nil

    if password_expiry_date
      @days_left = (password_expiry_date - Date.today).to_i
    else
      password_expiry_date = Date.today + 4.months
      User.save_property(user.user_id, 'password_expiry_date', password_expiry_date)
      @days_left = (password_expiry_date - Date.today).to_i 
    end

    @password_expired = true if @days_left < 0

    @super_user = true  if user.user_roles.collect{|x|x.role.downcase}.include?("superuser") rescue nil
    @regstration_clerk = true  if user.user_roles.collect{|x|x.role.downcase}.include?("regstration_clerk") rescue nil
    
    @show_set_date = false
    session[:datetime] = nil if session[:datetime].to_date == Date.today rescue nil
    @show_set_date = true unless session[:datetime].blank? 

    @facility = Location.find(session[:facility]).name rescue ""

    @location = Location.find(session[:location_id]).name rescue ""

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

    @user = User.find(session[:user_id]).name rescue ""

    @roles = User.find(session[:user_id]).user_roles.collect{|r| r.role} rescue []

    render :layout => "menu"
  end
 
  def new
    @ask_cell_phone = GlobalProperty.find_by_property("use_patient_attribute.cellPhone").property_value rescue nil
    @ask_home_phone = GlobalProperty.find_by_property("use_patient_attribute.homePhone").property_value rescue nil 
    @ask_office_phone = GlobalProperty.find_by_property("use_patient_attribute.officePhone").property_value rescue nil
    @occupations = occupations
  end

  def occupations
    ['','Driver','Housewife','Messenger','Business','Farmer','Salesperson','Teacher',
      'Student','Security guard','Domestic worker', 'Police','Office worker',
      'Preschool child','Mechanic','Prisoner','Craftsman','Healthcare Worker','Soldier'].sort.concat(["Other","Unknown"])
  end

  # List traditional authority containing the string given in params[:value]
  def traditional_authority
    district_id = District.find_by_name("#{params[:filter_value]}").id
    traditional_authority_conditions = ["name LIKE (?) AND district_id = ?", "#{params[:search_string]}%", district_id]

    traditional_authorities = TraditionalAuthority.find(:all,:conditions => traditional_authority_conditions, :order => 'name')
    traditional_authorities = traditional_authorities.map do |t_a|
      "<li value='#{t_a.name}'>#{t_a.name}</li>"
    end
    render :text => traditional_authorities.join('') + "<li value='Other'>Other</li>" and return
  end

  # Regions containing the string given in params[:value]
  def region
    region_conditions = ["name LIKE (?)", "#{params[:value]}%"]

    regions = Region.find(:all,:conditions => region_conditions, :order => 'name')
    regions = regions.map do |r|
      "<li value='#{r.name}'>#{r.name}</li>"
    end
    render :text => regions.join('') and return
  end

  # Districts containing the string given in params[:value]
  def district
    region_id = Region.find_by_name("#{params[:filter_value]}").id
    region_conditions = ["name LIKE (?) AND region_id = ? ", "#{params[:search_string]}%", region_id]

    districts = District.find(:all,:conditions => region_conditions, :order => 'name')
    districts = districts.map do |d|
      "<li value='#{d.name}'>#{d.name}</li>"
    end
    render :text => districts.join('') + "<li value='Other'>Other</li>" and return
  end

  # Villages containing the string given in params[:value]
  def village
    traditional_authority_id = TraditionalAuthority.find_by_name("#{params[:filter_value]}").id
    village_conditions = ["name LIKE (?) AND traditional_authority_id = ?", "#{params[:search_string]}%", traditional_authority_id]

    villages = Village.find(:all,:conditions => village_conditions, :order => 'name')
    villages = villages.map do |v|
      "<li value='#{v.name}'>#{v.name}</li>"
    end
    render :text => villages.join('') + "<li value='Other'>Other</li>" and return
  end

  # Landmark containing the string given in params[:value]
  def landmark
    landmarks = PersonAddress.find(:all, :select => "DISTINCT address1" , :conditions => ["city_village = (?) AND address1 LIKE (?)", "#{params[:filter_value]}", "#{params[:search_string]}%"])
    landmarks = landmarks.map do |v|
      "<li value='#{v.address1}'>#{v.address1}</li>"
    end
    render :text => landmarks.join('') + "<li value='Other'>Other</li>" and return
  end

  def identifiers
  end
 
  def demographics
    # Search by the demographics that were passed in and then return demographics
    people = Person.find_by_demographics(params)
    result = people.empty? ? {} : people.first.demographics
    render :text => result.to_json
  end
 
  def search
    found_person = nil
    if params[:identifier]
      local_result_set = Person.search_by_identifier(params[:identifier])

      # raise local_results.to_yaml
      ids_list = []
      local_results = []
      local_result_set.each{|persn|
        next if persn.to_s == "found duplicate identifiers"
        local_results << persn if !ids_list.include?(persn.person_id)
        ids_list << persn.id if !ids_list.include?(persn.person_id)        
      }  
     
      if local_result_set.length > 1
		redirect_to :action => 'duplicates' ,:search_params => params
        return	
        #@people = Person.search(params)
      elsif local_results.length == 1
		if create_from_dde_server
           dde_server = CoreService.get_global_property_value("dde_server_ip") rescue ""
           dde_server_username = CoreService.get_global_property_value("dde_server_username") rescue ""
           dde_server_password = CoreService.get_global_property_value("dde_server_password") rescue ""
           uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json"
           uri += "?value=#{params[:identifier]}"                                         
           output = RestClient.get(uri)                                          
           p = JSON.parse(output)                                                
           if p.count > 1 
            redirect_to :action => 'duplicates' ,:search_params => params
            return
          end
        end
        found_person = local_results.first
      else
        # TODO - figure out how to write a test for this
        # This is sloppy - creating something as the result of a GET
        found_person_data = Person.find_remote_by_identifier(params[:identifier])
        if found_person_data.to_s ==  'timeout' || found_person_data.to_s == 'creationfailed'
          
          flash[:error] = "Could not create patient due to loss of connection to server" if found_person_data.to_s == 'timeout'
          flash[:error] = "Was unable to create patient with the given details" if found_person_data.to_s == 'creationfailed'
          redirect_to :action => "index" and return
        else

          # raise found_person_data.to_yaml
          
          found_person = Person.create_from_form(found_person_data) unless found_person_data.nil?
        end
      end

     if found_person

        if create_from_dde_server
          patient = DDEService::Patient.new(found_person.patient)
 
	        national_id_replaced = patient.check_old_national_id(params[:identifier]) if found_person.patient.national_id.length != 6
			    if national_id_replaced.to_s == "true" || params[:identifier] != found_person.patient.national_id
						if params[:cat] && (params[:cat].downcase rescue "") != "mother" && params[:patient_id]	
							print_and_redirect("/patients/national_id_label?patient_id=#{found_person.id}", "/relationships/new?patient_id=#{params[:patient_id]}&relation=#{found_person.id }&cat=#{params[:cat]}") and return
						end
							print_and_redirect("/patients/national_id_label?patient_id=#{found_person.id}", next_task(found_person.patient))  and return          
          end
        end
				if params[:cat] && (params[:cat].downcase rescue "") != "mother" && params[:patient_id]

          redirect_to "/relationships/new?patient_id=#{params[:patient_id]}&relation=#{found_person.id
            }&cat=#{params[:cat]}" and return

				else

          redirect_to :controller => :encounters, :action => :new, :patient_id => found_person.id and return

        end
      end
    end
    @relation = params[:relation] if params[:relation]
    @search_results = {}
    @patients = []
    
		@people = Person.person_search(params)

    create_from_dde_server = CoreService.get_global_property_value('create.from.dde.server') rescue false

    (Person.search_from_remote(params) || []).each do |data|
	 		national_id = data["person"]["data"]["patient"]["identifiers"]["National id"] rescue nil
      national_id = data["person"]["value"] if national_id.blank? rescue nil
      national_id = data["npid"]["value"] if national_id.blank? rescue nil
      national_id = data["person"]["data"]["patient"]["identifiers"]["old_identification_number"] if national_id.blank? rescue nil

      next if national_id.blank?
      results = PersonSearch.new(national_id)
      results.national_id = national_id
      results.current_residence =data["person"]["data"]["addresses"]["city_village"]
      results.person_id = 0
      results.home_district = data["person"]["data"]["addresses"]["address2"]
      results.traditional_authority =  data["person"]["data"]["addresses"]["county_district"]
      results.name = data["person"]["data"]["names"]["given_name"] + " " + data["person"]["data"]["names"]["family_name"]
      gender = data["person"]["data"]["gender"]
      results.occupation = data["person"]["data"]["occupation"]
      results.sex = (gender == 'M' ? 'Male' : 'Female')
      results.birthdate_estimated = (data["person"]["data"]["birthdate_estimated"]).to_i
      results.birth_date = birthdate_formatted((data["person"]["data"]["birthdate"]).to_date , results.birthdate_estimated)
      results.birthdate = (data["person"]["data"]["birthdate"]).to_date
      results.age = cul_age(results.birthdate.to_date , results.birthdate_estimated)
      @search_results[results.national_id] = results

    end if create_from_dde_server 


		(@people || []).each do | person |
			patient = Person.get_patient(person) rescue nil
      next if patient.blank?
			results = PersonSearch.new(patient.national_id || patient.patient_id)
      results.national_id = patient.national_id
      results.birth_date = patient.birth_date
      results.current_residence = patient.current_residence
      results.guardian = patient.guardian
      results.person_id = patient.person_id
      results.home_district = patient.home_district
      results.current_district = patient.current_district
      results.traditional_authority = patient.traditional_authority
      results.mothers_surname = patient.mothers_surname
      results.dead = patient.dead
      results.arv_number = patient.arv_number
      results.eid_number = patient.eid_number
      results.pre_art_number = patient.pre_art_number
      results.name = patient.name
      results.sex = patient.sex
      results.age = patient.age
      @search_results.delete_if{|x,y| x == results.national_id }
      @patients << results
		end

		(@search_results || {}).each do |npid , data |
      @patients << data
    end


  end
 
  # This method is just to allow the select box to submit, we could probably do this better
  def select
 
    if params[:person] && params[:person][:id] != '0' && (Person.find(params[:person][:id]).dead == 1 rescue false)

			redirect_to :controller => :patients, :action => :show, :id => params[:person]
		else
      related_person = Person.search_by_identifier(params[:identifier]).first.patient rescue nil     
      related_person = ANCService.search_by_identifier(params[:identifier]).first.patient rescue nil if related_person.nil? and !params[:identifier].blank?
			params[:person] = Hash.new if !params[:person]
      params[:person][:id] = related_person.patient_id if related_person
    
      if !related_person.blank?
        if params[:identifier].length != 6 and create_from_dde_server
          dde_patient = DDEService::Patient.new(related_person)
		
          national_id_replaced = dde_patient.check_old_national_id(related_person.national_id)
			
          if national_id_replaced.to_s == "true" || params[:identifier] != related_person.national_id

             print_and_redirect("/patients/national_id_label?patient_id=#{related_person.id}",
          "/relationships/new?patient_id=#{params[:patient_id]}&relation=#{related_person.id}&cat=#{params[:cat]}") and return if params[:cat] != 'mother'

            print_and_redirect("/patients/national_id_label?patient_id=#{related_person.id}",
          "/patients/show/#{params[:person][:id]}?patient_id=#{related_person.id}&cat=#{params[:cat]}") and return if params[:cat] == 'mother'      
          else
            redirect_to "/relationships/new?patient_id=#{params[:patient_id]}&relation=#{related_person.id}&cat=#{params[:cat]}" and return if params[:cat] != 'mother'
            redirect_to "/patients/show/#{params[:person][:id]}?patient_id=#{related_person.id}&cat=#{params[:cat]}" and return if params[:cat] == 'mother'
         end          
        end
      end

			redirect_to "/patients/show/#{params[:person][:id]}" and return if (!params[:person][:id].blank? &&
          params[:person][:id] != '0') && (params[:cat] and !params[:cat].blank? and params[:cat] == "mother")

      redirect_to "/relationships/new?patient_id=#{params[:patient_id]}&relation=#{params[:person][:id]
            }&cat=#{params[:cat]}" and return if (params[:person][:id] rescue '0') != '0' and
        (params[:cat].downcase rescue "") != "mother"

      if params[:cat] and (params[:cat] == "child" && params[:cat] == "baby")
        redirect_to :action => :new_baby,
          :gender => params[:gender],
          :given_name => params[:given_name],
          :family_name => params[:family_name],
          :family_name2 => params[:family_name2],
          :address2 => params[:address2],
          :identifier => params[:identifier],
          :relation => params[:relation]
      else
        redirect_to :action => :new, :gender => params[:gender],
          :given_name => params[:given_name],
          :family_name => params[:family_name],
          :family_name2 => params[:family_name2],
          :address2 => params[:address2],
          :identifier => params[:ident] || params[:identifier],
          :relation => params[:relation],
          :patient_id => params[:patient_id],
          :cat => params[:cat]
      end
		end
  end
 
  def created

    remote_parent_server = GlobalProperty.find(:first, :conditions => {:property => "remote_servers.parent"}).property_value
    if !remote_parent_server.blank?
      found_person_data = Person.create_remote(params)
      #redirect to people index with flash notice if remote timed out or creation of patient on remote failed
      if found_person_data.to_s ==  'timeout' || found_person_data.to_s == 'creationfailed'
          
        flash[:error] = "Could not create patient due to loss of connection to server" if found_person_data.to_s == 'timeout'
        flash[:error] = "Was unable to create patient with the given details" if found_person_data.to_s == 'creationfailed'
        redirect_to :action => "index" and return
      end

      found_person = nil
      if found_person_data
        # diabetes_number = params[:person][:patient][:identifiers][:diabetes_number] rescue nil
        # found_person_data['person']['patient']['identifiers']['diabetes_number'] = diabetes_number if diabetes_number
        found_person = Person.create_from_form(found_person_data)
      end
              
      if found_person


        found_person.patient.national_id_label
        if params[:next_url]
          print_and_redirect("/patients/national_id_label/?patient_id=#{found_person.patient.id}",
            params[:next_url] + "?patient_id=#{ found_person.patient.id }")
        else
          print_and_redirect("/patients/national_id_label/?patient_id=#{found_person.patient.id}", next_task(found_person.patient))
        end
        
      else
        redirect_to :action => "index"
      end
    else
      person = Person.create_from_form(params[:person])

      if params[:next_url]
        print_and_redirect("/patients/national_id_label/?patient_id=#{person.patient.id}",
          params[:next_url] + "?patient_id=#{ person.patient.id }")
      elsif params[:person][:patient]
        person.patient.national_id_label
        print_and_redirect("/patients/national_id_label/?patient_id=#{person.patient.id}", next_task(person.patient))
      else
        redirect_to :action => "index"
      end
    end
  
  end


  def create

	if !params[:identifier].empty? 
		if params[:identifier].length == 6 
			person = ANCService.create_from_form(params[:person])
			if !person.nil?	
				patient_identifier = PatientIdentifier.new
				patient_identifier.type = PatientIdentifierType.find_by_name("National id")
				patient_identifier.identifier = params[:identifier]
				patient_identifier.patient = person.patient
				patient_identifier.save!
			end
		elsif params[:identifier] && create_from_dde_server
			person = ANCService.create_patient_from_dde(params) rescue nil
			if !person.nil?
				old_identifier = PatientIdentifier.new
				old_identifier.type = PatientIdentifierType.find_by_name("Old Identification Number")
				old_identifier.identifier = params[:identifier]
				old_identifier.patient = person.patient
				old_identifier.save!
			end
		else
		 	redirect_to "/" and return
		end
		if params[:encounter]
			encounter = Encounter.new(params[:encounter])
	   		encounter.patient_id = person.id
			encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
			encounter.save
		end
			print_and_redirect("/patients/national_id_label/?patient_id=#{person.patient.id}&cat=#{params[:cat]}", "/relationships/new?patient_id=#{params[:patient_id]}&relation=#{person.id}&cat=#{params[:cat]}") and return if !(params[:patient_id] rescue "").blank? and
        (params[:cat].downcase rescue "") != "mother"

		 print_and_redirect("/patients/national_id_label/?patient_id=#{person.patient.id}&cat=#{params[:cat]}", "/patients/show?patient_id=#{person.id}?cat=#{params[:cat]}") and return if !person.nil?

		redirect_to "/patients/show?patient_id=#{person.id}}" and return if !person.nil? 
	end
    person = ANCService.create_patient_from_dde(params) if create_from_dde_server

    if !person.blank?

      found_person = person

      if found_person

        found_person.patient.national_id_label
        
        if params[:next_url]
          if (params[:cat].downcase rescue "") == "mother"
            print_and_redirect("/patients/national_id_label/?patient_id=#{found_person.patient.id}",
              params[:next_url] + "?patient_id=#{ found_person.patient.id }") and return
          else
            redirect_to params[:next_url] + found_person.patient.id.to_s and return
          end
        else
          print_and_redirect("/patients/national_id_label/?patient_id=#{found_person.patient.id}", next_task(found_person.patient))
        end

      else
        redirect_to :action => "index"
      end
    else    
      
      remote_person = ANCService.create_remote(params) if create_from_remote   
      person = Person.create_from_form(remote_person) if create_from_remote      
      person = Person.create_from_form(params[:person]) if !create_from_remote

      if params[:next_url]
        if (params[:cat].downcase rescue "") == "mother"
          print_and_redirect("/patients/national_id_label/?patient_id=#{person.patient.id}",
            params[:next_url] + "?patient_id=#{ person.patient.id }") and return
        else
          redirect_to params[:next_url] + person.patient.id.to_s and return
        end

      elsif params[:person][:patient]
        person.patient.national_id_label
        print_and_redirect("/patients/national_id_label/?patient_id=#{person.patient.id}", next_task(person.patient))
      else
        redirect_to :action => "index"
      end
    end

  end
 
  # TODO refactor so this is restful and in the right controller.
  def set_datetime
    if request.post?
      unless params[:retrospective_date] == ""
        # set for 1 second after midnight to designate it as a retrospective date
        date_of_encounter = (params[:retrospective_date] + " " + Time.now.strftime("%H:%M")).to_time

        session[:datetime] = date_of_encounter if date_of_encounter.to_date != Date.today
      end
      redirect_to :action => "index"
    end
  end
 
  def reset_datetime
    session[:datetime] = nil
    redirect_to :action => "index" and return
  end

  # Adults: this is the access method for the adult section of the application
  def adults
    session["category"] = "adults"
    render :layout => "menu"
  end

  # Paediatrics this is the access method for the paediatrics section of the application
  def paeds
    session["category"] = "paeds"
    render :layout => "menu"
  end

  def create_maternity_patient
    remote_parent_server = GlobalProperty.find(:first, :conditions => {:property => "remote_servers.parent"}).property_value
    if !remote_parent_server.blank?
      found_person_data = Person.create_remote(params)
      #redirect to people index with flash notice if remote timed out or creation of patient on remote failed
      if found_person_data.to_s ==  'timeout' || found_person_data.to_s == 'creationfailed'

        flash[:error] = "Could not create patient due to loss of connection to server" if found_person_data.to_s == 'timeout'
        flash[:error] = "Was unable to create patient with the given details" if found_person_data.to_s == 'creationfailed'
        redirect_to :action => "index" and return
      end

      found_person = nil
      if found_person_data
        diabetes_number = params[:person][:patient][:identifiers][:diabetes_number] rescue nil
        found_person_data['person']['patient']['identifiers']['diabetes_number'] = diabetes_number if diabetes_number
        found_person = Person.create_from_form(found_person_data)
      end

      if found_person
        found_person.patient.national_id_label
        print_and_redirect("/patients/national_id_label/?patient_id=#{found_person.patient.id}", next_task(found_person.patient))
      else
        redirect_to :action => "index"
      end
    else
      # raise params.to_yaml
      person = Person.create_from_form(params[:person])

      if params[:person][:patient]
        person.patient.national_id_label
        print_and_redirect("/patients/national_id_label/?patient_id=#{person.patient.id}", next_task(person.patient))
      else
        redirect_to :action => "index"
      end
    end

  end

  def overview
    @types = GlobalProperty.find_by_property("statistics.show_encounter_types").property_value rescue EncounterType.all.map(&:name).join(",")
    @types = @types.split(/,/)

    @me = Encounter.statistics(@types, :conditions => 
        ['DATE(encounter_datetime) = DATE(NOW()) AND encounter.creator = ? AND encounter.location_id = ?',
        User.current_user.user_id, session[:location_id]])
    
    @today = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = DATE(NOW()) AND encounter.location_id = ?',
        session[:location_id]])
    
    @year = Encounter.statistics(@types, :conditions => ['YEAR(encounter_datetime) = YEAR(NOW()) AND encounter.location_id = ?',
        session[:location_id]])

    @ever = Encounter.statistics(@types, :conditions => ['encounter.location_id = ?', session[:location_id]])

    render :layout => false
  end

  def reports
    @location = Location.find(session[:facility]).name rescue ""

    render :layout => false
  end

  def admin
    render :layout => false
  end
 def serial_numbers
	@remaining_serial_numbers = SerialNumber.find(:all, :conditions => ["national_id IS NULL"]).size
	@print_string = (@remaining_serial_numbers ==1)?  "" + @remaining_serial_numbers.to_s + " Serial Number Remaining" : "" + @remaining_serial_numbers.to_s + " Serial Numbers Remaining"
	@limited_serial_numbers = (SerialNumber.all.size  <= 100) rescue false
	render :layout => false
  end  
  def create_batch
    @initial_numbers = SerialNumber.all.size

    if ((!params[:start_serial_number].blank? rescue false) && (!params[:end_serial_number].blank? rescue false) &&
          (params[:start_serial_number].to_i < params[:end_serial_number].to_i) rescue false)
      (params[:start_serial_number]..params[:end_serial_number]).each do |number|
        snum = SerialNumber.new()
        snum.serial_number = number
        snum.creator = params[:user_id]
        snum.save if (SerialNumber.find(number).nil? rescue true)
      end
      @final_numbers = initial_numbers = SerialNumber.all.size
    else
    end
    redirect_to "/"
  end
  def add_batch
 
  end
  
  def duplicates
    @duplicates = []
    people = Person.person_search(params[:search_params])
    people.each do |person|
      @duplicates << Person.get_patient(person)
    end unless people == "found duplicate identifiers"
 
    if create_from_dde_server
      @remote_duplicates = []
      Person.search_from_dde_by_identifier(params[:search_params][:identifier]).each do |person|
        @remote_duplicates << Person.get_dde_person(person)
      end
    end
    @selected_identifier = params[:search_params][:identifier]
    render :layout => 'menu'
  end
 
  def reassign_dde_national_id
    person = DDEService.reassign_dde_identification(params[:dde_person_id],params[:local_person_id])

	if params[:cat] && params[:session_patient_id]
			url = "/relationships/new?patient_id=#{params[:session_patient_id]}&relation=#{person.id}&cat=#{params[:cat]}"
			print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", url) and return
	end
	
    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end

 def remote_duplicates
    if params[:patient_id]
      @primary_patient = Person.get_patient(Person.find(params[:patient_id]))
    else
      @primary_patient = nil
    end
    
    @dde_duplicates = []
    if create_from_dde_server
      Person.search_from_dde_by_identifier(params[:identifier]).each do |person|
        @dde_duplicates << Person.get_dde_person(person)
      end
    end

    if @primary_patient.blank? and @dde_duplicates.blank?
      redirect_to :action => 'search',:identifier => params[:identifier] and return
    end
    render :layout => 'menu'
  end


  def reassign_national_identifier	

    patient = Patient.find(params[:person_id])
    if create_from_dde_server
		passed_params = Person.demographics(patient.person)
		new_npid = Person.create_from_dde_server_only(passed_params)
		npid = PatientIdentifier.new()
		npid.patient_id = patient.id
		npid.identifier_type = PatientIdentifierType.find_by_name('National id').patient_identifier_type_id
		npid.identifier = new_npid
		npid.save
    else
      PatientIdentifierType.find_by_name('National id').next_identifier({:patient => patient})
    end
    npid = PatientIdentifier.find(:first,
           :conditions => ["patient_id = ? AND identifier = ? 
           AND voided = 0", patient.id,params[:identifier]])
		if npid
			npid.voided = 1
			npid.void_reason = "Given another national ID"
			npid.date_voided = Time.now()
			npid.voided_by = current_user.id
			npid.save
   end

		if params[:cat] && params[:session_patient_id]
			url = "/relationships/new?patient_id=#{params[:session_patient_id]}&relation=#{patient.id}&cat=#{params[:cat]}"
			print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", url) and return
		end     
		print_and_redirect("/patients/national_id_label?patient_id=#{patient.id}", next_task(patient))
  end

  def create_person_from_dde                                                    
    person = DDEService.get_remote_person(params[:remote_person_id])                                                             
		#raise person.to_yaml
	if params[:cat] && params[:session_patient_id]
			url = "/relationships/new?patient_id=#{params[:session_patient_id]}&relation=#{person.id}&cat=#{params[:cat]}"
			print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", url) and return
	end                    
    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end
  
  protected
  
  def cul_age(birthdate , birthdate_estimated , date_created = Date.today, today = Date.today)
                                                                                
    # This code which better accounts for leap years                            
    patient_age = (today.year - birthdate.year) + ((today.month - birthdate.month) + ((today.day - birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)
                                                                                
    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date = birthdate                                                      
    estimate = birthdate_estimated == 1                                         
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && date_created.year == today.year) ? 1 : 0
  end                                                                           
                                                                                
  def birthdate_formatted(birthdate,birthdate_estimated)                        
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
  
end
