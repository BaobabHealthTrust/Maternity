require 'barby'
require 'barby/barcode/code_128'
require 'barby/outputter/rmagick_outputter'

class EncountersController < ApplicationController

  def create
	  @patient = Patient.find(params[:encounter][:patient_id])
    identifier = PatientIdentifier.find(:last, :conditions => ["patient_id = ? AND identifier_type = ?", @patient.id, PatientIdentifierType.find_by_name("National id")]).identifier rescue ""
 
    if((CoreService.get_global_property_value("create.from.dde.server") == true) && !@patient.nil? && identifier.length != 6)
      dde_patient = DDEService::Patient.new(@patient)
      identifier = dde_patient.get_full_identifier("National id").identifier rescue nil
      national_id_replaced = dde_patient.check_old_national_id(identifier) rescue nil
      if national_id_replaced.to_s == "true"
        print_and_redirect("/patients/national_id_label?patient_id=#{@patient.id}", "/patients/show?patient_id=#{@patient.id}") and return
      end
    end
		
    if (params["encounter"]["encounter_type_name"].upcase rescue "") == "UPDATE OUTCOME"
				
      params["observations"].each do |obs|
        if ((obs["concept_name"].upcase ==  "STATUS OF BABY") rescue false)
          obs.delete("value_coded_or_text")
        elsif ((obs["concept_name"].upcase == "BABY IDENTIFIER") rescue false)
          obs.delete("value_coded_or_text")
        end
      end
			@mother = MaternityService::Maternity.new(@patient) rescue nil
			@children = @mother.kids
			
			(params["baby_obs"].split("!") rescue []).each do |bb_ob|
				obs_value = bb_ob.split("--").last
				baby_id = @children.collect{|child| child.person_b if ((PersonName.find_by_person_id(child.person_b).given_name + "  " + PersonName.find_by_person_id(child.person_b).family_name).to_s == bb_ob.split("--").first) }

				baby_id = baby_id.reject {|b| !b }.first rescue nil
				baby_concept_id = ConceptName.find_by_name("STATUS OF BABY").concept_id rescue nil

				if !baby_id.blank? && (Person.find(baby_id).dead == true) 

					birth_outcome = Observation.find(:last, :order => ["date_created"], :conditions => ["person_id =? AND concept_id = ?",
              baby_id, ConceptName.find_by_name("BABY OUTCOME").concept_id]).answer_string

					obs_value = birth_outcome if not birth_outcome.match(/Alive/i)
					
				end rescue nil

				if not obs_value.blank? and not baby_id.blank? and not baby_concept_id.blank?
          params[:encounter][:encounter_datetime] = (params[:encounter][:encounter_datetime].to_date.strftime("%Y-%m-%d ") +
              Time.now.strftime("%H:%M")) rescue Time.now()
					
					baby_encounter = Encounter.new(params[:encounter])
					baby_encounter.patient_id = baby_id
					baby_encounter.save
	

					baby_ob = Observation.new				
					baby_ob.value_coded = ConceptName.find_by_name(obs_value).concept_id rescue nil
          baby_ob.value_text = obs_value
					baby_ob.person_id = baby_id
					baby_ob.concept_id = baby_concept_id
					baby_ob.encounter_id = baby_encounter.id
					baby_ob.obs_datetime = params[:encounter][:encounter_datetime]
					baby_ob.save
				
					if baby_ob.answer_string.strip.downcase != "alive"
            person = Person.find(baby_id)
            person.dead = true
            person.save
					end	

				end	
			end	

      delivered = (params["observations"].collect{|o| o if !o["value_coded_or_text"].nil? and o["value_coded_or_text"].upcase == "DELIVERED"}.compact.length	 > 0)
      baby_date_map = params[:baby_date_map].split("!") rescue nil

      if !baby_date_map.nil?
        baby_date_map.reject! { |b| b.empty? }
        count = 1
        params["observations"].each do |o|
          if (["BABY OUTCOME", "PRESENTATION", "DELIVERY MODE"].include?(o["concept_name"].upcase))
            o[:obs_datetime] = baby_date_map[count - 1].split(",")[1]
           
          end
        end
        count += 1
      end
    end

		if (params["encounter"]["encounter_type_name"].upcase rescue "") == "UPDATE OUTCOME" && params[:owner]		
			babies = MaternityService.extract_baby(params)

			@patient = Patient.find(params["encounter"]["patient_id"]) # rescue nil

			@maternity_patient = MaternityService::Maternity.new(@patient)
      created_baby = nil
      print_string = ""
      
			babies.each do |baby|
				# raise baby.to_yaml
				relationship = @maternity_patient.create_baby(baby)
				created_baby = Patient.find(relationship.person_b)

        mother_address = PersonAddress.find_by_person_id(relationship.person_a) rescue nil

        export_mother_addresss(relationship.person_a, created_baby.patient_id) rescue nil if !mother_address.blank? && !created_baby.blank?
      
				unless created_baby.blank?
					#Save encounter and observations with baby's patient id
					params[:encounter][:encounter_datetime] = (params[:encounter][:encounter_datetime].to_date.strftime("%Y-%m-%d ") +
              Time.now.strftime("%H:%M")) rescue Time.now()
			
					encounter = Encounter.new(params[:encounter])
					encounter.patient_id = created_baby.patient_id
					encounter.save

					(params[:observations] || []).each do |observation|
						# Check to see if any values are part of this observation
						# This keeps us from saving empty observations

						if !observation[:value_time].blank?
							observation["value_datetime"] = Time.now.strftime("%Y-%m-%d ") + observation["value_time"]
							observation.delete(:value_time)
						elsif observation[:value_time]
							observation.delete(:value_time)
						end
						
						observation.delete(:patient_id) if observation[:patient_id]
						observation.delete(:person_id)  if observation[:person_id]
					
						values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{|value_name|
							observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
						}.compact

						next if values.length == 0
						observation.delete(:value_text) 
						observation[:encounter_id]    = encounter.id
						observation[:person_id]     = encounter.patient_id
						
						Observation.create(observation) 
					end
				end
              
			end
 
			number_of_babies = params[:num_of_babies] rescue ""
			number_of_babies = params[:number_of_babies].to_i rescue -1  if number_of_babies.blank?
			number_of_babies = number_of_babies.to_i
			
			baby = params[:baby] rescue ""
			baby = -1 if baby.blank?
			baby = baby.to_i 
      
			print_and_redirect("/patients/delivery_print?patient_id=#{created_baby.patient_id}", "/encounters/baby_outcome?patient_id=#{params[:patient_id]}&baby=#{baby}&number_of_babies=#{number_of_babies}")  and return if (params[:baby] && params[:number_of_babies] && number_of_babies >= baby) || (params["observations"].collect{|o| o if !o["value_coded_or_text"].nil? and o["value_coded_or_text"].upcase == "DELIVERED"}.compact.length > 0)
		
  		print_and_redirect("/patients/delivery_print?patient_id=#{created_baby.patient_id}", "/patients/show/#{@patient.id}?skip_check=true") and return

    end

    params[:encounter][:encounter_datetime] = (params[:encounter][:encounter_datetime].to_date.strftime("%Y-%m-%d ") +
        Time.now.strftime("%H:%M")) rescue Time.now()
    
    encounter = Encounter.new(params[:encounter])
    encounter.save

    (params[:observations] || []).each do |observation|
      # Check to see if any values are part of this observation
      # This keeps us from saving empty observations

      if !observation[:value_time].blank?
        observation["value_datetime"] = Time.now.strftime("%Y-%m-%d ") + observation["value_time"]
        observation.delete(:value_time)
      elsif observation[:value_time]
        observation.delete(:value_time)
      end
   
      values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
      observation[:encounter_id]    = encounter.id
      # observation[:obs_datetime]    = (encounter.encounter_datetime.to_date.strftime("%Y-%m-%d ") + Time.now.strftime("%H:%M")) rescue Time.now()
      observation[:person_id]     ||= encounter.patient_id      
      # observation[:location_id]     ||= encounter.location_id
     
      x = Observation.create(observation) rescue nil
      if x.blank?
        observation[:value_text] = observation[:value_coded_or_text] if !observation[:value_coded_or_text].blank?
        observation.delete(:value_coded_or_text)
        Observation.create(observation)
      end
    end 
    referred_out = (params["observations"].collect{|o| o if !o["value_coded_or_text"].nil? and o["value_coded_or_text"].upcase == "REFERRED OUT"}.compact.length > 0) rescue false;
    if referred_out
      redirect_to "/encounters/new/refer_out?patient_id=#{@patient.id}" and return
    end
		if (params["encounter"]["encounter_type_name"].upcase rescue "") == "UPDATE OUTCOME" 
			num = params[:observations].collect{|o| o[:value_coded_or_text] if o[:concept_name].upcase == "NUMBER OF BABIES"}.compact.first rescue nil
			
			number_of_babies = num.to_i rescue nil unless num.blank?
			if number_of_babies.blank? 
				number_of_babies = params[:num_of_babies] rescue "" unless number_of_babies.blank?
				number_of_babies = params[:number_of_babies].to_i rescue -1  if number_of_babies.blank?
				number_of_babies = number_of_babies.to_i
			end

			redirect_to "/encounters/baby_outcome?patient_id=#{params[:patient_id]}&baby=0&number_of_babies=#{number_of_babies}"  and return if (params["observations"].collect{|o| o if !o["value_coded_or_text"].nil? and o["value_coded_or_text"].upcase == "DELIVERED"}.compact.length > 0)

		end

		if encounter.patient.current_visit.encounters.active.collect{|e|
        e.observations.collect{|o|
          o.answer_string if ["PATIENT DIED", "DISCHARGED", "REFERRED OUT"].include?(o.answer_string.to_s.upcase)         
        }.compact if e.type.name.upcase.eql?("UPDATE OUTCOME")
      }.compact.collect{|p| true if p.to_s.upcase.include?("DISCHARGED")}.compact.include?(true) == true

      encounter.patient.current_visit.update_attributes(:end_date => Time.now.strftime("%Y-%m-%d %H:%M:%S"))

      print_and_redirect("/encounters/label/?encounter_id=#{encounter.id}",
        "/people") and return if (encounter.type.name.upcase == "UPDATE OUTCOME")
      # return next_task(@patient)
      redirect_to next_task(@patient) and return
    end
    
    if encounter.patient.current_visit.encounters.active.collect{|e|
        e.observations.collect{|o|
          o.answer_string if o.answer_string.to_s.upcase.include?("PATIENT DIED") || 
            o.answer_string.to_s.upcase.include?("DISCHARGED")
        }.compact if e.type.name.upcase.eql?("UPDATE OUTCOME")
      }.compact.collect{|p| true if p.to_s.upcase.include?("PATIENT DIED") ||
          p.to_s.upcase.include?("DISCHARGED")}.compact.include?(true) == true

      encounter.patient.current_visit.update_attributes(:end_date => Time.now.strftime("%Y-%m-%d %H:%M:%S"))

      redirect_to "/people" and return
    end
    if delivered && delivered > 0
      redirect_to "/patients/show/#{@patient.id}" and return
    end
    if params[:next_url]

      if (encounter.type.name.upcase == "UPDATE OUTCOME" && encounter.to_s.upcase.include?("ADMITTED"))
        print_and_redirect("/encounters/label/?encounter_id=#{encounter.id}", params[:next_url]) and return if (encounter.type.name.upcase == \
            "UPDATE OUTCOME" && encounter.to_s.upcase.include?("ADMITTED"))
        return
      else
        redirect_to params[:next_url] and return
      end
    else
      if (encounter.type.name.upcase == "UPDATE OUTCOME" && encounter.to_s.upcase.include?("ADMITTED"))
        print_and_redirect("/encounters/label/?encounter_id=#{encounter.id}", next_task(@patient)) and return if (encounter.type.name.upcase == \
            "UPDATE OUTCOME" && encounter.to_s.upcase.include?("ADMITTED"))
        return
      else
        redirect_to next_task(@patient)
      end
    end  
  end

  def export_mother_addresss(mother_id, baby_id)

    mother_address = PersonAddress.find_by_person_id(mother_id)

    keys = mother_address.attributes.keys.delete_if{|key| key.blank? || key.match(/person_id|person_address_id|date_created/)}
    baby_address = PersonAddress.new
    baby_address.person_id = baby_id

    keys.each do |ky|
      baby_address["#{ky}"] = mother_address["#{ky}"]
    end

    baby_address.save

  end
  
  def new
	
		@patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil    
		@mother = MaternityService::Maternity.new(@patient) rescue nil
		@children = @mother.kids
    
    @children_names = @children.collect{|child| PersonName.find_by_person_id(child.person_b).given_name + "  " + 				PersonName.find_by_person_id(child.person_b).family_name if child.date_created > 1.month.ago}
		@children_names = @children_names.concat(["Other"]) unless (@children_names.length < 1 rescue false)

    @pending_birth_reports = Relationship.find_by_sql("SELECT * FROM relationship r
      INNER JOIN person p ON p.person_id = r.person_b AND p.dead = 0 AND r.voided = 0
      WHERE r.person_a = #{@patient.patient_id} AND (SELECT COUNT(*) FROM birth_report WHERE person_id = r.person_b) = 0
      AND (SELECT value_datetime FROM obs WHERE person_id = r.person_b AND concept_id = (SELECT concept_id FROM concept_name
      WHERE name = 'Date Of Delivery' LIMIT 1)) >= DATE_ADD(NOW(), INTERVAL -14 DAY)
      AND r.relationship = (SELECT relationship_type_id FROM relationship_type WHERE a_is_to_b = 'Mother' AND b_is_to_a = 'Child')
      ") rescue []
    
    session[:auto_load_forms] = true
    #raise @children_names.to_yaml

    @facility_outcomes =  JSON.parse(GlobalProperty.find_by_property("facility.outcomes").property_value) rescue {}
    #raise @facility_outcomes.to_yaml
    @new_hiv_status = params[:new_hiv_status]
    @admission_wards = [' '] + GlobalProperty.find_by_property('facility.login_wards').property_value.split(',') rescue []
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) 

    @diagnosis_type = params[:diagnosis_type]
    @facility = (GlobalProperty.find_by_property("facility.name").property_value rescue "") # || (Location.find(session[:facility]).name rescue "")    

    if params[:encounter_type] && params[:encounter_type].downcase == "observations_patient_history"
      #check if we have known LMP from ANC
      anc_link = CoreService.get_global_property_value("anc_link")
      anc_link = "http://#{anc_link}/encounters/probe_lmp"
      
      if anc_link.present?
        lmp_params = {"national_id" => @patient.national_id}
        
        @lmp = JSON.parse(RestClient.post(anc_link, lmp_params))["lmp"] rescue nil
        params[:lmp] = @lmp
      end
    
    end      
   
    @encounters = @patient.current_visit.encounters.active.find(:all, :conditions =>
        ["encounter_type = ? OR encounter_type = ? OR encounter_type = ? OR encounter_type = ? " +
          "OR encounter_type = ? OR encounter_type = ?",
        EncounterType.find_by_name("OBSERVATIONS").encounter_type_id,
        EncounterType.find_by_name("DIAGNOSIS").encounter_type_id,
        EncounterType.find_by_name("SOCIAL HISTORY").encounter_type_id,
        EncounterType.find_by_name("CURRENT BBA DELIVERY").encounter_type_id,
        EncounterType.find_by_name("ABDOMINAL EXAMINATION").encounter_type_id,
        EncounterType.find_by_name("PHYSICAL EXAMINATION BABY").encounter_type_id]).collect{|e|
      e.observations.collect{|o| o.concept.name.name.upcase}
    }.join(", ") rescue ""

    @anc_encounters = AncConnection::Patient.find(session["patient_anc_map"][@patient.id]).encounters.current.collect{|e|
      e.observations.collect{|o|
        o.concept.concept_names.map(& :name).last.upcase
      }
    }.join(", ") rescue ""

    @encounters = @encounters + (@encounters == "" ? @anc_encounters : ", " + @anc_encounters)

    @anc_encounters = AncConnection::Patient.find(session["patient_anc_map"][@patient.id],
      :conditions => ["encounter_type = ?",
        AncConnection::EncounterType.find_by_name("OBSTETRIC HISTORY").encounter_type_id]).encounters.collect{|e|
      e.observations.collect{|o|
        o.concept.concept_names.map(& :name).last.upcase
      }
    }.join(", ") rescue ""

    @anc_patient = ANCService::ANC.new(@patient) if @patient.present?

    @encounters = @encounters + (@encounters == "" ? @anc_encounters : ", " + @anc_encounters)

    @lmp = Observation.find(:all, :conditions => ["concept_id IN (?) AND person_id = 34 AND encounter_id IN (?)",
        ConceptName.find_by_name("LAST MENSTRUAL PERIOD").concept_id, @patient.encounters.collect{|e| e.id}],
      :order => :obs_datetime).last.value_datetime rescue nil

    @location = Location.current_location.name || Location.find(session[:location_id]).name
        
    @last_location = @patient.encounters.find(:last).location_id rescue nil
    
    redirect_to "/" and return unless @patient
    redirect_to next_task(@patient) and return unless params[:encounter_type]
    redirect_to :action => :create, 'encounter[encounter_type_name]' => params[:encounter_type].upcase, 'encounter[patient_id]' => @patient.id and return if ['registration'].include?(params[:encounter_type])
    render :action => params[:encounter_type] if params[:encounter_type]
  end

  def diagnoses
    
    search_string         = (params[:search_string] || '').upcase

    diagnosis_concepts    = Concept.find_by_name("MATERNITY DIAGNOSIS LIST").concept_members_names.sort.uniq rescue []

    @results = diagnosis_concepts.collect{|e| e if e.downcase.include?(search_string.downcase)}
    
    render :text => "<li>" + @results.join("</li><li>") + "</li>"
    
  end

  def procedure_diagnoses
   
    procedure = params[:procedure].upcase.gsub("_", " ")
    procedure ="Exploratory laparatomy +/- adnexectomy".upcase  if params[:procedure] == "laparatomy"
    procedure ="Evacuation/Manual Vacuum Aspiration".upcase  if params[:procedure] == "evacuation"
    search_string         = (params[:search_string] || '').upcase

    diagnosis_concepts    = Concept.find_by_name(procedure).concept_members_names.sort.uniq rescue []
    if params[:procedure].humanize.match(/Incision And Drainage/i)
      range = ConceptName.find(:all, :conditions => ["name = 'Incision And Drainage'"]).collect{|c| c.concept_id} rescue []
      c_answer = ConceptAnswer.find(:all, :conditions => ["concept_id IN (?)", range])
      diagnosis_concepts = c_answer.collect{|d| ConceptName.find_by_concept_id(d.answer_concept).name}
    end

    if params[:procedure].humanize.match(/Malsupilisation/i)
      range = ConceptName.find(:all, :conditions => ["name = 'Malsupilisation'"]).collect{|c| c.concept_id} rescue []
      c_answer = ConceptAnswer.find(:all, :conditions => ["concept_id IN (?)", range])
      diagnosis_concepts = c_answer.collect{|d| ConceptName.find_by_concept_id(d.answer_concept).name}
    end
    
    @results = diagnosis_concepts.collect{|e| e if e.downcase.include?(search_string.downcase)}
    @results = @results.insert(@results.length - 1, @results.delete_at(@results.index("Other"))) rescue @results
    
    render :text => "<li>" + @results.join("</li><li>") + "</li>"
    
  end

  def treatment
    search_string = (params[:search_string] || '').upcase
    filter_list = params[:filter_list].split(/, */) rescue []
    valid_answers = []
    unless search_string.blank?
      drugs = Drug.find(:all, :conditions => ["retired = 0 AND name LIKE ?", '%' + search_string + '%'])
      valid_answers = drugs.map {|drug| drug.name.upcase }
    end
    treatment = ConceptName.find_by_name("TREATMENT").concept
    previous_answers = Observation.find_most_common(treatment, search_string)
    suggested_answers = (previous_answers + valid_answers).reject{|answer| filter_list.include?(answer) }.uniq[0..10]
    render :text => "<li>" + suggested_answers.join("</li><li>") + "</li>"
  end
  
  def locations
    search_string = (params[:search_string] || 'neno').upcase
    filter_list = params[:filter_list].split(/, */) rescue []
    locations =  Location.find(:all, :select =>'name', :conditions => ["retired = 0 AND name LIKE ?", '%' + search_string + '%'])
    render :text => "<li>" + locations.map{|location| location.name }.join("</li><li>") + "</li>"
  end

  def simple_graph
    @patient = Patient.find(params[:patient_id] || session[:patient_id])
    @graph_data = @patient.person.observations.find_by_concept_name("WEIGHT (KG)").
      sort_by{|obs| obs.obs_datetime}.
      map{|x| [(x.obs_datetime.to_i * 1000), x.value_numeric]}.to_json
    #render :layout => false
  end

  def diagnoses_index
    @patient    = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @diagnosis  = @patient.current_diagnoses["DIAGNOSIS"] rescue []

    render :template => 'encounters/diagnoses_index', :layout => 'menu'
  end

  def confirmatory_evidence
    @patient = Patient.find(params[:patient_id] || params[:id] || session[:patient_id]) rescue nil
    @primary_diagnosis = @patient.current_diagnoses([ConceptName.find_by_name('PRIMARY DIAGNOSIS').concept_id]).last rescue nil
    @requested_test_obs = @patient.current_diagnoses([ConceptName.find_by_name('TEST REQUESTED').concept_id]) rescue []
    @result_available_obs = @patient.current_diagnoses([ConceptName.find_by_name('RESULT AVAILABLE').concept_id]) rescue []
    
    best_tests_hash = DiagnosisTree.best_tests
    @diagnosis_name = @primary_diagnosis.answer_concept_name.name rescue 'NONE'
    @best_tests = Array.new()
    best_tests_hash.each{|test,diagnoses| @best_tests << test if diagnoses.include?("#{@diagnosis_name}")}

    #dont show confirmatory evidence page if the diagnosis does not have a test
    redirect_to "/prescriptions/?patient_id=#{@patient.id}" and return if @best_tests.empty?

    render :template => 'encounters/confirmatory_evidence', :layout => 'menu'
  end

  def create_observation
    observation = Hash.new()

    observation[:patient_id] = params[:patient_id]
    observation[:concept_name] = params[:concept_name]
    observation[:person_id] = params[:person_id]
    observation[:obs_datetime] = params[:obs_datetime]
    observation[:encounter_id] = params[:encounter_id]
    #observation[:value_coded_or_text] = params[:value_coded_or_text]
    observation[:value_coded] = Concept.find_by_name(params[:value_coded]).concept_id rescue Concept.find_by_name('UNKNOWN').concept_id
    observation[:value_text] = params[:value_text]

    Observation.create(observation)

    redirect_to next_discharge_task(Patient.find(params[:patient_id]))
  end

  def outcome
    session[:auto_load_forms] = true
  end
   
  def admit_patient
    session[:auto_load_forms] = true
  end

  # create_adult_influenza_entry: is a method to save the results of an influenza
  # Adult question set
  def create_adult_influenza_entry
=begin
    @found = false

    (params[:observations] || []).each{|observation|
      # Check to see if any values are part of this observation
      # This keeps us from saving empty observations
      values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      if(observation[:parent_concept_name])
        if(observation[:parent_concept_name] == "ADMISSION CRITERIA" && observation["value_coded_or_text"] == "Yes")
          params[:next_url] = "/patients/chronic_conditions?patient_id=" + params[:encounter][:patient_id]
          @found = true
          # Get out if you've found a 'Yes'
          break
        end
      end
      
    }
=end
    create_influenza_data
  end

  # create_paeds_influenza_entry is a method to save the results of an influenza
  # Paediatrics' question set
  def create_paeds_influenza_entry
=begin
    @found = false

    (params[:observations] || []).each{|observation|
      # Check to see if any values are part of this observation
      # This keeps us from saving empty observations
      values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      if(observation[:parent_concept_name])
        if(observation[:parent_concept_name] == "ADMISSION CRITERIA" && observation["value_coded_or_text"] == "Yes")
          params[:next_url] = "/patients/chronic_conditions?patient_id=" + params[:encounter][:patient_id]
          @found = true
          # Get out if you've found a 'Yes'
          break
        end
      end

    }
=end
    create_influenza_data
  end

  # create_chronics is a method to save the results of an influenza
  # Chronic Conditions question set
  def create_chronics
    create_influenza_data
  end

  # create_lab_entry is a method to save requested lab tests grouped by accession number
  def create_lab_entry

    encounter = Encounter.new(params[:encounter])
    
    # We need the time as well here which was not captured by session[:datetime]
    encounter.encounter_datetime = Time.now   #session[:datetime] unless session[:datetime].blank?
    encounter.save

    identifier = PatientIdentifier.new(params[:patient_identifier])
    identifier.save

    (params[:observations] || []).each{|observation|
      # Check to see if any values are part of this observation
      # This keeps us from saving empty observations
      values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
      observation[:encounter_id] = encounter.id
      observation[:obs_datetime] = encounter.encounter_datetime ||= Time.now()
      observation[:person_id] ||= encounter.patient_id

      observation[:concept_name] = "LAB TEST SERIAL NUMBER"

      value_coded_or_text = observation[:value_coded_or_text]
      observation[:value_coded_or_text] = identifier.identifier
          
      #observation[:value_text] = identifier.identifier

      o = Observation.create(observation)

      value_coded_or_text.each{|obs|

        observation[:concept_name] = "REQUESTED LAB TEST SET"
        observation[:obs_group_id] = o.obs_id
        observation[:encounter_id] = encounter.id
        observation[:obs_datetime] = encounter.encounter_datetime ||= Time.now()
        observation[:person_id] ||= encounter.patient_id
        observation[:value_text] = nil
        observation[:value_coded_or_text] = obs
        Observation.create(observation)

      }
    }

    @patient = Patient.find(params[:encounter][:patient_id])
    
    # redirect to a custom destination page 'next_url'
    if encounter.type.name == "LAB"
      print_and_redirect("/encounters/label/?encounter_id=#{encounter.id}", next_task(@patient))  if encounter.type.name == "LAB"
      return
    elsif(params[:next_url])
      redirect_to params[:next_url] and return
    else
      redirect_to next_task(@patient)
    end
    
  end

  # Save Adults, Paediatric, Chronic Conditions Influenza Data and Lab Tests based on the
  # Encounter::create method from the Diabetes Module
  def create_influenza_data
   
    encounter = Encounter.new(params[:encounter])
    encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank? or encounter.name == 'DIABETES TEST'
    encounter.save

    (params[:observations] || []).each{|observation|
      # Check to see if any values are part of this observation
      # This keeps us from saving empty observations
      values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
      observation[:encounter_id] = encounter.id
      observation[:obs_datetime] = encounter.encounter_datetime ||= Time.now()
      observation[:person_id] ||= encounter.patient_id
      observation[:concept_name] ||= "OUTPATIENT DIAGNOSIS" if encounter.type.name == "OUTPATIENT DIAGNOSIS"

      if(observation[:measurement_unit])
        observation[:value_numeric] = observation[:value_numeric].to_f * 18 if ( observation[:measurement_unit] == "mmol/l")
        observation.delete(:measurement_unit)
      end

      if(observation[:parent_concept_name])
        concept_id = Concept.find_by_name(observation[:parent_concept_name]).id rescue nil
        observation[:obs_group_id] = Observation.find(:first, :conditions=> ['concept_id = ? AND encounter_id = ?',concept_id, encounter.id]).id rescue ""
        observation.delete(:parent_concept_name)
      end

      extracted_value_numerics = observation[:value_numeric]
      if (extracted_value_numerics.class == Array)

        extracted_value_numerics.each do |value_numeric|
          observation[:value_numeric] = value_numeric
          Observation.create(observation)
        end
      else
        Observation.create(observation)
      end
    }
    @patient = Patient.find(params[:encounter][:patient_id])

    # redirect to a custom destination page 'next_url'
    if(params[:next_url])
      redirect_to params[:next_url] and return
    else
      redirect_to next_task(@patient)
    end
    
  end

  def label
    send_label(Encounter.find(params[:encounter_id]).label)
  end

  # Capture Lab Test Results
  def lab_results_entry
    render :layout => 'menu'
  end

  def search_lab_test
  end
  
  # Capture Lab Test Results
  def show_lab_tests
    @obs = Observation.search_lab_test(params[:identifier])
    
    @patient = Patient.find(@obs.person_id) rescue nil

    @encounter_names = Observation.search_actual_tests(@obs.obs_id) rescue nil

    @obs_encounters = Observation.lab_tests_encounters(params[:identifier]) rescue nil

    @tests = @obs_encounters.collect {|enc|
      enc.to_s
    } rescue []

    @enc_names = @obs_encounters.map{|encounter| encounter.name}.uniq rescue []

    render :layout => 'menu'
  end

  # Edit the selected Lab Test
  def edit_test
    @obs = Observation.search_lab_test(params[:identifier])

    @patient = Patient.find(@obs.person_id) rescue nil

    @encounter_names = Observation.search_actual_tests(@obs.obs_id)

    @gram_stain_result = ConceptName.gram_stain_result_set

    @gram_stain_organisms = ConceptName.gram_stain_organisms_set

    @antibiotic_results = ConceptName.antibiotic_results

    @appearance_options = ConceptName.appearance_options

    @virus_species = ConceptName.virus_species
    
  end
  
  def create_encounter

    encounter = Encounter.new(params[:encounter])
    encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank? or encounter.name == 'DIABETES TEST'
    encounter.save

    (params[:observations] || []).each{|observation|
      # Check to see if any values are part of this observation
      # This keeps us from saving empty observations
      values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
      observation[:encounter_id] = encounter.id
      observation[:obs_datetime] = encounter.encounter_datetime ||= Time.now()
      observation[:person_id] ||= encounter.patient_id
      observation[:concept_name] ||= "OUTPATIENT DIAGNOSIS" if encounter.type.name == "OUTPATIENT DIAGNOSIS"

      if(observation[:measurement_unit])
        observation[:value_numeric] = observation[:value_numeric].to_f * 18 if ( observation[:measurement_unit] == "mmol/l")
        observation.delete(:measurement_unit)
      end

      if(observation[:parent_concept_name])
        concept_id = Concept.find_by_name(observation[:parent_concept_name]).id rescue nil
        observation[:obs_group_id] = Observation.find(:first, :conditions=> ['concept_id = ? AND encounter_id = ?',concept_id, encounter.id]).id rescue ""
        observation.delete(:parent_concept_name)
      end

      extracted_value_numerics = observation[:value_numeric]
      if (extracted_value_numerics.class == Array)

        extracted_value_numerics.each do |value_numeric|
          observation[:value_numeric] = value_numeric
          Observation.create(observation)
        end
      else
        Observation.create(observation)
      end
    }
    @patient = Patient.find(params[:encounter][:patient_id])

    # redirect to a custom destination page 'next_url'
    if(params[:next_url])
      redirect_to params[:next_url] and return
    else
      redirect_to next_task(@patient)
    end

  end

  def referral
    @patient = Patient.find(params[:patient_id])

    @roles = User.find(session[:user_id]).user_roles.collect{|r| r.role} # rescue []
  end

  def update_hiv_status
    @patient = Patient.find(params[:patient_id])
  end

  def procedure_index
    @patient    = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @procedures  = @patient.current_procedures["PROCEDURE DONE"] rescue []

    render :template => '/encounters/procedure_index', :layout => 'menu'
  end


  def death_report_printable
    @patient    = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @anc_patient = ANCService::ANC.new(@patient) if @patient.present?    
  
    @user_name = User.find(params[:user_id] || session[:user_id]).name rescue nil 
    @user_roles = User.find(params[:user_id] || session[:user_id]).user_roles.collect{|r| r.role}.flatten.to_s

    @facility = (GlobalProperty.find_by_property("facility.name").property_value rescue "") ||
      (Location.find(session[:facility]).name rescue "")
    @facility_date = (session[:datetime].to_date rescue Date.today)

    @patient.create_barcode

    @encounters = {}
    @died_encounter = {}

    d_encounter = @patient.died_encounter
    
    d_encounter.observations.each{|obs|

      value = nil

      unless @died_encounter.has_key?("USER_NAME")
        @died_encounter["USER_NAME"] = d_encounter.provider.name
      end

      unless @died_encounter.has_key?("USER_TITLE")
        @died_encounter["USER_TITLE"] = d_encounter.provider.user_roles.collect{|r| r.role}.flatten.to_s
      end
      
      if obs.answer_string.upcase.strip == "CURRENT FACILITY"
        value = @facility
      else
        value = obs.answer_string rescue nil
      end

      if obs.concept.name.name.upcase.strip == "TIME OF DEATH" && obs.answer_string.present?
        check_digit = (((value.split(":")[0].to_i)  > 11 ? "PM" : "AM") rescue "")
        value += " #{check_digit}"
      end

      @died_encounter[obs.concept.name.name.upcase.strip] = value rescue nil
      
    } rescue nil
    
    render :layout => false
  end

  def observations_printable
    @patient    = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    
    @user = params[:user_id]
    @user_name = User.find(@user).name rescue nil if @user.present?
    @user_name = User.find(session[:user_id]).name rescue nil if @user_name.blank?

    @facility = (GlobalProperty.find_by_property("facility.name").property_value rescue "") ||
      (Location.find(session[:facility]).name rescue "")
    
    @patient.create_barcode

    @encounters = {}
    @babyencounters = {}
    @bbaencounters = {}
    @outpatient_diagnosis = {}
    @referral = {}

    @deliveries = 0
    @gravida = 0
    @abortions = 0
    
    if !(session["patient_anc_map"][@patient.id] rescue nil).nil?
      @ancpatient = AncConnection::Patient.find(session["patient_anc_map"][@patient.id]) rescue nil

      if !@ancpatient.nil?
        @anc_patient = ANCService::ANC.new(@ancpatient)

        @pregnancies = @anc_patient.active_range

        @range = []

        @pregnancies = @pregnancies[1]

        @pregnancies.each{|preg|
          @range << preg[0].to_date
        }

        @encs = AncConnection::Encounter.find(:all, :conditions => ["patient_id = ? AND encounter_type = ?",
            @ancpatient.id, AncConnection::EncounterType.find_by_name("OBSTETRIC HISTORY").id]).length

        if @encs > 0
          @deliveries = AncConnection::Observation.find(:last,
            :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @ancpatient.id,
              AncConnection::Encounter.find(:all).collect{|e| e.encounter_id},
              AncConnection::ConceptName.find_by_name('PARITY').concept_id]).answer_string.to_i rescue nil

          @deliveries = @deliveries + (@range.length > 0 ? @range.length - 1 : @range.length) if !@deliveries.nil?

          @gravida = AncConnection::Observation.find(:last,
            :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @ancpatient.id,
              AncConnection::Encounter.find(:all).collect{|e| e.encounter_id},
              AncConnection::ConceptName.find_by_name('GRAVIDA').concept_id]).answer_string.to_i rescue nil

          @abortions = AncConnection::Observation.find(:last,
            :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @ancpatient.id,
              AncConnection::Encounter.find(:all).collect{|e| e.encounter_id},
              AncConnection::ConceptName.find_by_name('NUMBER OF ABORTIONS').concept_id]).answer_string.to_i rescue nil
        end
      end
    end
    
    @patient.current_visit.encounters.active.find(:all, :conditions => ["encounter_type = ?",
        EncounterType.find_by_name("IS PATIENT REFERRED?").encounter_type_id]).each{|e|
      e.observations.each{|o|
        if o.concept.name.name == "IS PATIENT REFERRED?"
          if !@referral[o.concept.name.name.upcase]
            @referral[o.concept.name.name.upcase] = []
          end

          @referral[o.concept.name.name.upcase] << o.answer_string
        elsif o.concept.name.name.include?("TIME")
          @referral[o.concept.name.name.upcase] = o.value_datetime.to_date
        else
          @referral[o.concept.name.name.upcase] = o.answer_string
        end
      }
    } rescue {}

    @patient.current_visit.encounters.active.find(:all, :conditions => ["encounter_type = ? OR encounter_type = ?",
        EncounterType.find_by_name("DIAGNOSIS").encounter_type_id,
        EncounterType.find_by_name("OBSERVATIONS").encounter_type_id]).each{|e|
      e.observations.each{|o|
        if o.concept.name.name.upcase == "DIAGNOSIS" || o.concept.name.name.upcase == "ADMISSION DIAGNOSIS"
          if !@outpatient_diagnosis[o.concept.name.name.upcase]
            @outpatient_diagnosis[o.concept.name.name.upcase] = []
          end

          @outpatient_diagnosis[o.concept.name.name.upcase] << o.answer_string
        end
      }
    } rescue {}

    @patient.current_visit.encounters.active.find(:all, :conditions => ["encounter_type = ? " +
          "OR encounter_type = ?",
        EncounterType.find_by_name("OBSERVATIONS").encounter_type_id,
        EncounterType.find_by_name("ABDOMINAL EXAMINATION").encounter_type_id]).each{|e|
      e.observations.each{|o|
        if o.concept.name.name.upcase == "DELIVERY MODE"
          if !@encounters[o.concept.name.name.upcase]
            @encounters[o.concept.name.name.upcase] = []
          end
          
          @encounters[o.concept.name.name.upcase] << o.answer_string
        elsif o.concept.name.name.upcase.include?("TIME")
          @encounters[o.concept.name.name.upcase] = o.value_datetime.strftime("%H:%M")
        else
          name = o.concept.name.name.upcase.gsub('"', "").strip
          @encounters[name] = o.answer_string
        end
      }
    } rescue {}

    @patient.current_visit.encounters.active.find(:all, :conditions => ["encounter_type = ? ",
        EncounterType.find_by_name("CURRENT BBA DELIVERY").encounter_type_id]).each{|e|
      e.observations.each{|o|
        if o.concept.name.name.upcase == "DELIVERY MODE"
          if !@bbaencounters[o.concept.name.name.upcase]
            @bbaencounters[o.concept.name.name.upcase] = []
          end
          
          @bbaencounters[o.concept.name.name.upcase] << o.answer_string
        elsif o.concept.name.name.upcase.include?("TIME")
          @bbaencounters[o.concept.name.name.upcase] = o.value_datetime.strftime("%H:%M")
        else
          @bbaencounters[o.concept.name.name.upcase] = o.answer_string
        end
      }
    } rescue {}

    @patient.current_visit.encounters.active.find(:all, :conditions => ["encounter_type = ?",
        EncounterType.find_by_name("PHYSICAL EXAMINATION BABY").encounter_type_id]).each{|e|
      e.observations.each{|o|
        if o.concept.name.name.upcase == "CONDITION OF BABY AT ADMISSION" ||
            o.concept.name.name.upcase == "WEIGHT (KG)" ||
            o.concept.name.name.upcase == "TEMPERATURE (C)" ||
            o.concept.name.name.upcase == "RESPIRATORY RATE" ||
            o.concept.name.name.upcase == "PULSE" ||
            o.concept.name.name.upcase == "CORD CLEAN" ||
            o.concept.name.name.upcase == "CORD TIED" ||
            o.concept.name.name.upcase == "SPECIFY" ||
            o.concept.name.name.upcase == "ABDOMEN"
          if !@babyencounters[o.concept.name.name.upcase]
            @babyencounters[o.concept.name.name.upcase] = []
          end
          
          @babyencounters[o.concept.name.name.upcase] << o.answer_string
        elsif o.concept.name.name.upcase.include?("TIME")
          @babyencounters[o.concept.name.name.upcase] = o.value_datetime.strftime("%H:%M")
        else
          @babyencounters[o.concept.name.name.upcase] = o.answer_string
        end
      }
    } rescue {}

    # raise @referral.to_yaml
    
    @nok = (@patient.next_of_kin["GUARDIAN FIRST NAME"] + " " + @patient.next_of_kin["GUARDIAN LAST NAME"] +
        " - " + @patient.next_of_kin["GUARDIAN RELATIONSHIP TO CHILD"] + " " +
        (@patient.next_of_kin["NEXT OF KIN TELEPHONE"] ? " (" + @patient.next_of_kin["NEXT OF KIN TELEPHONE"] +
          ")" : "")) rescue ""
    
    @religion = (@patient.next_of_kin["RELIGION"] ? (@patient.next_of_kin["RELIGION"].upcase == "OTHER" ?
          @patient.next_of_kin["OTHER"] : @patient.next_of_kin["RELIGION"]) : "") rescue ""
    
    @education = @patient.next_of_kin["EDUCATION LEVEL"] rescue ""
    
    @position = (@encounters["CEPHALIC"] ? @encounters["CEPHALIC"] : "") +
      (@encounters["BREECH"] ? @encounters["BREECH"] : "") + (@encounters["FACE"] ? @encounters["FACE"] : "") +
      (@encounters["SHOULDER"] ? @encounters["SHOULDER"] : "") rescue ""
  
    if @encounters["PRESENTATION"] && @encounters["PRESENTATION"].upcase == "BREECH"
      @position = @encounters["BREECH DELIVERY"] if  @encounters["BREECH DELIVERY"].downcase.match("sacro")
    end

    if (@encounters["ARV START DATE"].match("/") rescue false)
      mon = [" ", "Jan","Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
      year = @encounters["ARV START DATE"].split("/")[2].to_i
      month = @encounters["ARV START DATE"].split("/")[1]
      month = mon.index(month).to_i
      day = @encounters["ARV START DATE"].split("/")[0].to_i
      date_started_arvs = Date.new(year, month, day)
      months_from_start_date = date_started_arvs.year * 12 + date_started_arvs.month
      months_today = Date.today.year * 12 + Date.today.month
      @period_on_arvs = months_today - months_from_start_date
      @period_on_arvs_string = (@period_on_arvs > 11)? ((@period_on_arvs/12).to_s == 1? (@period_on_arvs/12).to_s + " Yr   " +
          (@period_on_arvs%12).to_s + " months": (@period_on_arvs./12).to_s + " Yrs " + (@period_on_arvs%12).to_s + " months") :  (@period_on_arvs%12).to_s + " months"
    else
      @period_on_arvs_string = ""
    end
    lmp_date = (@encounters["DATE OF LAST MENSTRUAL PERIOD"].to_date + 7.days) rescue nil
    current_date = (session[:datetime]? session[:datetime] : Date.today).to_date rescue nil
  
    @edd_weeks = ((current_date - lmp_date).days).to_i/(60 * 60 * 24 * 7) rescue "Unknown"
    
    render :layout => false
  end
  def print_note
    # raise request.remote_ip.to_yaml

    location = request.remote_ip rescue ""
    @patient    = Patient.find(params[:patient_id]) rescue (Patient.find(params[:id]) rescue (Patient.find(session[:patient_id]) rescue nil))
    zoom = CoreService.get_global_property_value("report.zoom.percentage")/100.0 rescue 1
    if @patient
      current_printer = ""

      wards = GlobalProperty.find_by_property("facility.ward.printers").property_value.split(",") rescue []

      printers = wards.each{|ward|
        current_printer = ward.split(":")[1] if ward.split(":")[0].upcase == location
      } rescue []

      t1 = Thread.new{
        Kernel.system "wkhtmltopdf --zoom #{zoom} -s A4 http://" +
          request.env["HTTP_HOST"] + "\"/encounters/observations_printable/" +
          @patient.patient_id.to_s + "?patient_id=#{@patient.patient_id}&user_id=#{params[:user_id]}&ret=#{params[:ret]}"+ "\" /tmp/output-" + params[:user_id].to_s + ".pdf \n"
      }

      t2 = Thread.new{
        sleep(5)
        Kernel.system "lp #{(!current_printer.blank? ? '-d ' + current_printer.to_s : "")} /tmp/output-" +
          session[:user_id].to_s + ".pdf\n"
      }

      t3 = Thread.new{
        sleep(10)
        Kernel.system "rm /tmp/output-" + session[:user_id].to_s + ".pdf\n"
      }


    end


    redirect_to "/encounters/new/observations_print?patient_id=#{@patient.id}"+
      (params[:ret] ? "&ret=" + params[:ret] : "") and return
  end
  
  def print_death_note
    # raise request.remote_ip.to_yaml

    location = request.remote_ip rescue ""
    @patient    = Patient.find(params[:patient_id]) rescue (Patient.find(params[:id] || params[:patient_id]) rescue (Patient.find(session[:patient_id]) rescue nil))
    zoom = CoreService.get_global_property_value("report.zoom.percentage")/100.0 rescue 1
    if @patient
      current_printer = ""

      wards = GlobalProperty.find_by_property("facility.ward.printers").property_value.split(",") rescue []

      printers = wards.each{|ward|
        current_printer = ward.split(":")[1] if ward.split(":")[0].upcase == location
      } rescue []
     
      t1 = Thread.new{
        Kernel.system "wkhtmltopdf --zoom 1.5 -s A4 http://" +
          request.env["HTTP_HOST"] + "\"/encounters/death_report_printable/" +
          @patient.patient_id.to_s + "?patient_id=#{@patient.patient_id}&user_id=#{params[:user_id]}"+ "\" /tmp/outputd-" + params[:user_id].to_s + ".pdf \n"
      }

      t2 = Thread.new{
        sleep(5)
        Kernel.system "lp #{(!current_printer.blank? ? '-d ' + current_printer.to_s : "")} /tmp/outputd-" +
          params[:user_id].to_s + ".pdf\n"
      }

      t3 = Thread.new{
        sleep(10)
        Kernel.system "rm /tmp/outputd-" + params[:user_id].to_s + ".pdf\n"
      }

    
    end


    redirect_to "/encounters/new/death_report_print?patient_id=#{@patient.id}"+
      (params[:ret] ? "&ret=" + params[:ret] : "") and return
  end

  def static_locations
    search_string = (params[:search_string] || "").upcase
    
    locations = []

    File.open(RAILS_ROOT + "/public/data/locations.txt", "r").each{ |loc|
      locations << loc if loc.upcase.strip.match(search_string)
    }

    render :text => "<li></li><li " + locations.map{|location| "value=\"#{location}\">#{location}" }.join("</li><li ") + "</li>"

  end

  def print_discharge_note
    if params[:encounter_id]
      print_and_redirect("/encounters/label/?encounter_id=#{params[:encounter_id]}",
        "/patients/end_visit?patient_id=#{ params[:patient_id] }")
    else
      redirect_to "/people/index"
    end
  end
 
  def baby_outcome
    @patient = Patient.find(params[:patient_id])
  end
end
