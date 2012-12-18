require 'rqrcode'

class PatientsController < ApplicationController
  before_filter :find_patient, :except => [:void]
  
  def show
    # raise link_to_anc.to_yaml
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil 
   # last_visit = Visit.find(:last, :conditions => ["patient_id = ?", @patient.id])
    @maternity_patient = ANCService::ANC.new(@patient)

    if link_to_anc
      if session["patient_anc_map"].nil?
        session["patient_anc_map"] = {}
      end

      if session["patient_anc_map"][@patient.id].nil?
        session["patient_anc_map"][@patient.id] = AncConnection::PatientIdentifier.search_by_identifier(@maternity_patient.national_id).id
      end
    end
    
    @last_location = @patient.encounters.find(:last).location_id rescue nil
       # @last_visit_closed = !last_visit.end_date.nil?
    
    if (session[:location_id] != @last_location) && (params[:skip_check] ? (params[:skip_check] == "true" ? false : true ) : true)
      params[:skip_check] = false
      redirect_to "/encounters/new/admit_patient?patient_id=#{@patient.id}" and return
    end


    #find the user priviledges
    @super_user = false
    @clinician  = false
    @doctor     = false
    @regstration_clerk  = false

    @user = User.find(session[:user_id])
    @user_privilege = @user.user_roles.collect{|x|x.role.downcase}

    if @user_privilege.include?("superuser")
      @super_user = true
    elsif @user_privilege.include?("clinician")
      @clinician  = true
    elsif @user_privilege.include?("doctor")
      @doctor     = true
    elsif @user_privilege.include?("regstration_clerk")
      @regstration_clerk  = true
    end  
    
    outcome = @patient.current_outcome
    @encounters = @patient.encounters.active.find(:all) rescue []
    @encounter_names = @patient.encounters.active.map{|encounter| encounter.name.upcase}.uniq rescue []

    @discharged = @patient.encounters.active.find(:all, :conditions =>
        ["encounter_type = ?", EncounterType.find_by_name("UPDATE OUTCOME").id]).collect{|e|
      e.observations.collect{|o|
        o.answer_string if o.answer_string.upcase.include?("DISCHARGED")
      }
    }.uniq.compact.join(", ") rescue []

    @result = []
    
    @ref = @patient.encounters.active.find(:all, :conditions =>
        ["encounter_type = ?", EncounterType.find_by_name("REFER PATIENT OUT?").id]).collect{|e|
      e.observations.collect{|o|
        @result << [o.encounter_id, o.answer_string]
      }
    } rescue []

    @refer_out = @result.join(", ").include?("Yes")

    @patient_dead = false

    for encounter in @encounters do
      if encounter.to_s.upcase.include?("PATIENT DIED")
        @patient_dead = true
      end
    end

    @past_diagnoses = @patient.previous_visits_diagnoses.collect{|o|
      o.diagnosis_string
    }.delete_if{|x|
      x == ""
    }

    @link_to_anc = link_to_anc
    
    # raise @encounter_names.include?("Refer patient out?".upcase).to_yaml

    @past_treatments = @patient.visit_treatments
    session[:auto_load_forms] = false if params[:auto_load_forms] == 'false'
    session[:outcome_updated] = true if !outcome.nil?
    session[:admitted] = false if params[:admitted] == 'false'
    session[:confirmed] = true if params[:confirmed] == 'true'
    session[:diagnosis_done] = true if params[:diagnosis_done] == 'true'
    session[:hiv_status_updated] = true if params[:hiv_status_updated] == 'true'
    session[:prescribed] = true if params[:prescribed] == 'true'
    #print_and_redirect("/patients/print_visit?patient_id=#{@patient.id}", next_task(@patient)) and return if session[:prescribed] = true 
    redirect_to next_discharge_task(@patient) and return if session[:auto_load_forms] == true && session[:admit] == false
    redirect_to next_admit_task(@patient) and return if session[:auto_load_forms] == true && session[:admit] == true
    render :template => 'patients/show', :layout => 'dynamic-dashboard' # 'menu'
    #
    # render :template => 'patients/showed', :layout => 'menu'
    
  end

  def void    
    @encounter = Encounter.find(params[:encounter_id])
    ActiveRecord::Base.transaction do
      @encounter.observations.each{|obs| obs.void! }    
      @encounter.orders.each{|order| order.void! }    
      @encounter.void!
    end

    unless params[:identifier].nil?
      redirect_to :controller => 'encounters', :action => 'show_lab_tests', :identifier => params[:identifier] and return
    else
      show and return
    end
  end
  
  def print_registration
    @patient = Patient.find(params[:id] || params[:patient_id] || session[:patient_id]) rescue nil
    print_and_redirect("/patients/national_id_label/?patient_id=#{@patient.id}", next_task(@patient))  
  end
  
  def print_visit
    @patient = Patient.find(params[:id] || params[:patient_id] || session[:patient_id]) rescue nil
    print_and_redirect("/patients/visit_label/?patient_id=#{@patient.id}", next_task(@patient))  
  end
  
  def national_id_label
    print_string = Patient.find(params[:patient_id]).national_id_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end
  
  def visit_label
    print_string = Patient.find(params[:patient_id]).visit_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def hiv_status
    #find patient object and arv number
    @patient = Patient.find(params[:patient_id] || params[:id] || session[:patient_id]) rescue nil 
    @remote_art_info = @patient.remote_art_info rescue {}
    @arv_number = @remote_art_info['person']['arv_number'] rescue nil 
    @hiv_test_date = @patient.hiv_test_date
    @status = @patient.hiv_status
    
    render :template => 'patients/hiv_status', :layout => 'menu'
  end

  def discharge
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    session[:auto_load_forms] = true
    session[:outcome_updated] = false
    session[:hiv_status_updated] = false
    session[:confirmed] = false
    session[:diagnosis_done] = false
    session[:prescribed] = false
    session[:admit] = false
    redirect_to next_discharge_task(@patient)
  end

  def admit
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    session[:auto_load_forms] = true
    session[:diagnosis_done] = false
    session[:admitted] = true
    session[:admit] = true
    redirect_to next_admit_task(@patient)
  end

  def end_visit
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    current_visit = @patient.current_visit
    primary_diagnosis = @patient.current_diagnoses["DIAGNOSIS"] rescue nil
    treatment = @patient.current_treatment_encounter.orders.active rescue []
    session[:admitted] = false

    # if (@patient.current_outcome && primary_diagnosis) or ['DEAD','REFERRED'].include?(@patient.current_outcome)
    
    current_visit.ended_by = session[:user_id]
    current_visit.end_date = @patient.current_treatment_encounter.encounter_datetime rescue Time.now()
    current_visit.save

    # print_and_redirect("/patients/print_visit?patient_id=#{@patient.id}", close_visit) and return

=begin
    elsif @patient.admitted_to_ward && session[:ward] == 'WARD 4B'

      print_and_redirect("/patients/print_registration?patient_id=#{@patient.id}", close_visit) and return

    end
=end
    
    redirect_to close_visit and return
    
  end

  def demographics
    @person = Patient.find(params[:person_id]) rescue nil
    @update_patient = ANCService::ANC.new(@person) rescue nil

    @national_id = @update_patient.national_id_with_dashes rescue nil

    @first_name = @person.person.names.first.given_name rescue nil
    @last_name = @person.person.names.first.family_name rescue nil
    @maiden_name = @person.person.names.first.family_name2 rescue nil
    @birthdate = @update_patient.birthdate_formatted rescue nil
    @gender = @update_patient.sex rescue ''

    @current_village = @person.person.addresses.first.city_village rescue ''
    @current_ta = @person.person.addresses.first.county_district rescue ''
    @current_district = @person.person.addresses.first.state_province rescue ''
    @home_district = @person.person.addresses.first.address2 rescue ''

    @primary_phone = @update_patient.phone_numbers[:cell_phone_number] rescue ''
    @secondary_phone = @update_patient.phone_numbers["Home Phone Number"] rescue ''

    @occupation = @update_patient.get_attribute("occupation") rescue ''

    @baby = (!params[:cat].nil? ? (params[:cat].downcase == "baby" ? true : false) : false)

    render :template => 'patients/demographics', :layout => 'menu'

  end

  def edit_demographics
    # @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @person = Patient.find(params[:person_id]) rescue nil
    @field = params[:field]
    render :partial => "edit_demographics", :field =>@field, :layout => true and return
  end

  def update_demographics
    ANCService.update_demographics(params)
    redirect_to :action => 'demographics', :patient_id => params['patient_id'],
      :person_id => params['person_id'], :cat => params[:cat] and return
  end

  # Diagnosis: method for accessing the diagnosis view
  def diagnosis
    
    redirect_to :controller => 'encounters',
      :action => 'diagnoses_index',
      :patient_id => params['patient_id'] and return

  end

  # Treatment method for accessing the treatment view
  def treatment
    
    redirect_to :controller => 'prescriptions',
      :action => 'index',
      :patient_id => params['patient_id'] and return
    
  end

  # Influenza method for accessing the influenza view
  def influenza
    
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @person = Person.find(@patient.patient_id)

    @gender = @person.gender
    
  end

  # Influenza method for accessing the influenza view
  def chronic_conditions

    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @person = Person.find(@patient.patient_id)

    @gender = @person.gender

  end

  # Specimen Labelling method for accessing the specimen labelling view
  def specimen_labelling
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    render :layout => "menu"
  end

  # Lab Results method for accessing the lab results view
  def lab_results
    #find the user priviledges
    @super_user = false
    @clinician  = false
    @doctor     = false
    @regstration_clerk  = false

    @user = User.find(session[:user_id])
    @user_privilege = @user.user_roles.collect{|x|x.role.downcase}

    if @user_privilege.include?("superuser")
      @super_user = true
    elsif @user_privilege.include?("clinician")
      @clinician  = true
    elsif @user_privilege.include?("doctor")
      @doctor     = true
    elsif @user_privilege.include?("regstration_clerk")
      @regstration_clerk  = true
    end
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    outcome = @patient.current_outcome
    @encounters = @patient.current_visit.encounters.active.find(:all) rescue []
    @encounter_names = @patient.encounters.active.map{|encounter| encounter.name}.uniq rescue []
    @past_diagnosis = @patient.visit_diagnoses
    @past_treatments = @patient.visit_treatments
    session[:auto_load_forms] = false if params[:auto_load_forms] == 'false'
    session[:outcome_updated] = true if !outcome.nil?
    session[:admitted] = false if params[:admitted] == 'false'
    session[:confirmed] = true if params[:confirmed] == 'true'
    session[:diagnosis_done] = true if params[:diagnosis_done] == 'true'
    session[:hiv_status_updated] = true if params[:hiv_status_updated] == 'true'
    session[:prescribed] = true if params[:prescribed] == 'true'
    #print_and_redirect("/patients/print_visit?patient_id=#{@patient.id}", next_task(@patient)) and return if session[:prescribed] = true
    redirect_to next_discharge_task(@patient) and return if session[:auto_load_forms] == true && session[:admit] == false
    redirect_to next_admit_task(@patient) and return if session[:auto_load_forms] == true && session[:admit] == true
    render :template => 'patients/lab_results', :layout => 'menu'

  end

  # new_test_set: method for accessing the new_test_set view
  def new_test_set
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
  end

  def print_lab_identifier
    if(params[:identifier])
      print_string = Patient.find(params[:patient_id]).print_lab_identifier(params[:identifier]) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
      send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
    end
  end

  def visit_summary
    @super_user = false
    @clinician  = false
    @doctor     = false
    @regstration_clerk  = false

    @user = User.find(session[:user_id])
    @user_privilege = @user.user_roles.collect{|x|x.role.downcase}

    if @user_privilege.include?("superuser")
      @super_user = true
    elsif @user_privilege.include?("clinician")
      @clinician  = true
    elsif @user_privilege.include?("doctor")
      @doctor     = true
    elsif @user_privilege.include?("regstration_clerk")
      @regstration_clerk  = true
    end
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    outcome = @patient.current_outcome rescue ""

    @encounters = @patient.encounters.find(:all, 
      :conditions => ["DATE(encounter_datetime) = ?", (session[:datetime] ? session[:datetime].to_date : Date.today)]) rescue []

    @encounter_names = @patient.encounters.active.map{|encounter| encounter.name}.uniq rescue []

    @past_diagnoses = @patient.previous_visits_diagnoses.collect{|o|
      o.diagnosis_string
    }.delete_if{|x|
      x == ""
    } rescue []

    @past_treatments = @patient.visit_treatments rescue []	
    render :layout => false
  end

  def visit_history
    @super_user = false
    @clinician  = false
    @doctor     = false
    @regstration_clerk  = false

    @user = User.find(session[:user_id])
    @user_privilege = @user.user_roles.collect{|x|x.role.downcase}

    if @user_privilege.include?("superuser")
      @super_user = true
    elsif @user_privilege.include?("clinician")
      @clinician  = true
    elsif @user_privilege.include?("doctor")
      @doctor     = true
    elsif @user_privilege.include?("regstration_clerk")
      @regstration_clerk  = true
    end
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    outcome = @patient.current_outcome rescue ""
    @encounters = @patient.current_visit.encounters.active.find(:all) rescue []
    @encounter_names = @patient.current_visit.encounters.active.map{|encounter| encounter.name}.uniq rescue []

    @past_diagnoses = @patient.past_history rescue []  # @patient.previous_visits_diagnoses.collect{|o|
    # o.diagnosis_string
    # }.delete_if{|x|
    #  x == ""
    # }

    @past_treatments = @patient.visit_treatments rescue []
    @previous_visits  = get_previous_encounters(params[:patient_id])

    @encounter_dates = @previous_visits.map{|encounter| encounter.encounter_datetime.to_date}.uniq.reverse.first(6) rescue []

    @past_encounter_dates = []

    @encounter_dates.each do |encounter|
      @past_encounter_dates << encounter if encounter < (session[:datetime].to_date rescue Date.today.to_date)
    end

    render :layout => false
  end
  
  def get_previous_encounters(patient_id)
    previous_encounters = Encounter.find(:all,
      :conditions => ["encounter.voided = ? and patient_id = ?", 0, patient_id],
      :include => [:observations]
    )

    return previous_encounters
  end
  
  def social_history
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil 
    
    relation = ["Mother",
      "Husband",
      "Sister",
      "Friend",
      "Aunt",
      "Neighbour",
	  "Mother-in-law",
	  "Landlord/Landlady",	  
      "Other"]
    
    @relation = Observation.find(:all, :joins => [:concept, :encounter], 
      :conditions => ["obs.concept_id = ? AND NOT value_text IN (?) AND " + 
          "encounter_type = ?", 
        ConceptName.find_by_name("OTHER RELATIVE").concept_id, relation, 
        EncounterType.find_by_name("SOCIAL HISTORY").id]).collect{|o| o.value_text}
    
    @relation = relation + @relation
	@relation = @relation.collect{|rel| rel.gsub('-', ' ').gsub('_', ' ').squish.titleize}.uniq

    religions = ["Jehovahs Witness",  
      "Roman Catholic", 
      "Presbyterian (C.C.A.P.)",
      "Seventh Day Adventist", 
      "Baptist", 
      "Moslem",
      "Other"]
    
    @religions = Observation.find(:all, :joins => [:concept, :encounter], 
      :conditions => ["obs.concept_id = ? AND NOT value_text IN (?) AND " + 
          "encounter_type = ?", 
        ConceptName.find_by_name("Other").concept_id, religions, 
        EncounterType.find_by_name("SOCIAL HISTORY").id]).collect{|o| o.value_text}
    
    @religions = religions + @religions
    
    # raise @religions.to_yaml
  end

  def tab_obstetric_history
    @patient = AncConnection::Patient.find(params[:patient_id]) rescue nil
    
    @anc_patient = ANCService::ANC.new(@patient) rescue nil

    @pregnancies = @anc_patient.active_range if !@anc_patient.nil?

    @range = []

    @pregnancies = @pregnancies[1] if !@anc_patient.nil?

    @pregnancies.each{|preg|
      @range << preg[0].to_date
    } if !@anc_patient.nil?


    @encs = AncConnection::Encounter.find(:all, :conditions => ["patient_id = ? AND encounter_type = ?",
        @patient.id, AncConnection::EncounterType.find_by_name("OBSTETRIC HISTORY").id]).length rescue 0

    if @encs > 0
      @deliveries = AncConnection::Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          AncConnection::Encounter.find(:all).collect{|e| e.encounter_id},
          AncConnection::ConceptName.find_by_name('PARITY').concept_id]).answer_string.to_i rescue nil

      @deliveries = @deliveries + (@range.length > 0 ? @range.length - 1 : @range.length) if !@deliveries.nil?

      @gravida = AncConnection::Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          AncConnection::Encounter.find(:all).collect{|e| e.encounter_id},
          AncConnection::ConceptName.find_by_name('GRAVIDA').concept_id]).answer_string.to_i rescue nil

      @multipreg = AncConnection::Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          AncConnection::Encounter.find(:all, :conditions => ["encounter_type = ?",
              AncConnection::EncounterType.find_by_name("OBSTETRIC HISTORY").id]).collect{|e| e.encounter_id},
          AncConnection::ConceptName.find_by_name('MULTIPLE GESTATION').concept_id]).answer_string.upcase.squish rescue nil

      @abortions = AncConnection::Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          AncConnection::Encounter.find(:all).collect{|e| e.encounter_id},
          AncConnection::ConceptName.find_by_name('NUMBER OF ABORTIONS').concept_id]).answer_string.to_i rescue nil

      @stillbirths = AncConnection::Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          AncConnection::Encounter.find(:all).collect{|e| e.encounter_id},
          AncConnection::ConceptName.find_by_name('STILL BIRTH').concept_id]).answer_string.upcase.squish rescue nil

      #Observation.find(:all, :conditions => ["person_id = ? AND encounter_id IN (?) AND value_coded = ?", 40, Encounter.find(:all, :conditions => ["patient_id = ?", 40]).collect{|e| e.encounter_id}, ConceptName.find_by_name('Caesarean section').concept_id])

      @csections = AncConnection::Observation.find(:all,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND (concept_id = ? AND value_coded = ?)", @patient.id,
          AncConnection::Encounter.find(:all, :conditions => ["patient_id = ? AND encounter_type = ?", @patient.id,
              AncConnection::EncounterType.find_by_name("OBSTETRIC HISTORY").id]).collect{|e| e.encounter_id},
          AncConnection::ConceptName.find_by_name('Caesarean section').concept_id,
          AncConnection::ConceptName.find_by_name('Yes').concept_id]).length rescue nil

      @vacuum = AncConnection::Observation.find(:all,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND value_coded = ?", @patient.id,
          AncConnection::Encounter.find(:all, :conditions => ["patient_id = ? AND encounter_type = ?",
              @patient.id, AncConnection::EncounterType.find_by_name("OBSTETRIC HISTORY").id]).collect{|e| e.encounter_id},
          AncConnection::ConceptName.find_by_name('Vacuum extraction delivery').concept_id]).length rescue nil

      @symphosio = AncConnection::Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          AncConnection::Encounter.find(:all).collect{|e| e.encounter_id},
          AncConnection::ConceptName.find_by_name('SYMPHYSIOTOMY').concept_id]).answer_string.upcase.squish rescue nil

      @haemorrhage = AncConnection::Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          AncConnection::Encounter.find(:all).collect{|e| e.encounter_id},
          AncConnection::ConceptName.find_by_name('HEMORRHAGE').concept_id]).answer_string.upcase.squish rescue nil

      @preeclampsia = AncConnection::Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          AncConnection::Encounter.find(:all).collect{|e| e.encounter_id},
          AncConnection::ConceptName.find_by_name('PRE-ECLAMPSIA').concept_id]).answer_string.upcase.squish rescue nil

      @eclampsia = AncConnection::Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          AncConnection::Encounter.find(:all).collect{|e| e.encounter_id},
          AncConnection::ConceptName.find_by_name('ECLAMPSIA').concept_id]).answer_string.upcase.squish rescue nil
    end

    # raise @eclampsia.blank?.to_yaml

    render :layout => false
  end

  def tab_medical_history
    @patient = AncConnection::Patient.find(params[:patient_id]) rescue nil

    @anc_patient = ANCService::ANC.new(@patient) rescue nil

    @asthma = AncConnection::Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        AncConnection::ConceptName.find_by_name('ASTHMA').concept_id]).answer_string.upcase.squish rescue nil

    @hyper = AncConnection::Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        AncConnection::ConceptName.find_by_name('HYPERTENSION').concept_id]).answer_string.upcase.squish rescue nil

    @diabetes = AncConnection::Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        AncConnection::ConceptName.find_by_name('DIABETES').concept_id]).answer_string.upcase.squish rescue nil

    @epilepsy = AncConnection::Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        AncConnection::ConceptName.find_by_name('EPILEPSY').concept_id]).answer_string.upcase.squish rescue nil

    @renal = AncConnection::Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        AncConnection::ConceptName.find_by_name('RENAL DISEASE').concept_id]).answer_string.upcase.squish rescue nil

    @fistula = AncConnection::Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        AncConnection::ConceptName.find_by_name('FISTULA REPAIR').concept_id]).answer_string.upcase.squish rescue nil

    @deform = AncConnection::Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        AncConnection::ConceptName.find_by_name('SPINE OR LEG DEFORM').concept_id]).answer_string.upcase.squish rescue nil

    @surgicals = AncConnection::Observation.find(:all, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ? AND encounter_type = ?",
            @patient.id, AncConnection::EncounterType.find_by_name("SURGICAL HISTORY").id]).collect{|e| e.encounter_id},
        AncConnection::ConceptName.find_by_name('PROCEDURE DONE').concept_id]).collect{|o|
      "#{o.answer_string.squish} (#{AncConnection::Observation.find(o.id + 1,
      :conditions => ["concept_id = ?", AncConnection::ConceptName.find_by_name("Date Received").concept_id]
      ).value_datetime.to_date.strftime('%d-%b-%Y') rescue "Unknown" })"} rescue []

    @age = @anc_patient.age rescue 0

    @age = (Person.find(params[:internal_id]).age rescue 0) if @age == 0

    render :layout => false
  end

  def tab_visit_history
    @patient = AncConnection::Patient.find(params[:patient_id]) rescue nil

    @anc_patient = ANCService::ANC.new(@patient) rescue nil

    @current_range = @anc_patient.active_range((params[:target_date] ?
          params[:target_date].to_date : (session[:datetime] ? session[:datetime].to_date : Date.today))) if !@anc_patient.nil?

    # raise @current_range.to_yaml

    @encounters = {}

    @patient.encounters.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?",
        @current_range[0]["START"], @current_range[0]["END"]]).collect{|e|
      @encounters[e.encounter_datetime.strftime("%d/%b/%Y")] = {"USER" => User.find(e.creator).name }
    } if !@anc_patient.nil?

    @patient.encounters.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?",
        @current_range[0]["START"], @current_range[0]["END"]]).collect{|e|
      @encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase] = ({} rescue "") if !e.type.nil?
    } if !@anc_patient.nil?

    @patient.encounters.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?",
        @current_range[0]["START"], @current_range[0]["END"]]).collect{|e|
      if !e.type.nil?
        e.observations.each{|o|
          if o.to_a[0]
            if o.to_a[0].upcase == "DIAGNOSIS" && @encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][o.to_a[0].upcase]
              @encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][o.to_a[0].upcase] += "; " + o.to_a[1]
            else
              @encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][o.to_a[0].upcase] = o.to_a[1]
              if o.to_a[0].upcase == "PLANNED DELIVERY PLACE"
                @current_range[0]["PLANNED DELIVERY PLACE"] = o.to_a[1]
              elsif o.to_a[0].upcase == "MOSQUITO NET"
                @current_range[0]["MOSQUITO NET"] = o.to_a[1]
              end
            end
          end
        }
      end
    } if !@anc_patient.nil?

    @drugs = {};
    @other_drugs = {};
    main_drugs = ["TTV", "SP", "Fefol", "NVP", "TDF/3TC/EFV"]

    @patient.encounters.find(:all, :order => "encounter_datetime DESC",
      :conditions => ["encounter_type = ? AND encounter_datetime >= ? AND encounter_datetime <= ?",
        AncConnection::EncounterType.find_by_name("TREATMENT").id, @current_range[0]["START"], @current_range[0]["END"]]).each{|e|
      @drugs[e.encounter_datetime.strftime("%d/%b/%Y")] = {} if !@drugs[e.encounter_datetime.strftime("%d/%b/%Y")];
      @other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")] = {} if !@other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")];
      e.orders.each{|o|
        if main_drugs.include?(o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")])
          if o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")] == "NVP"
            if o.drug_order.drug.name.upcase.include?("ML")
              @drugs[e.encounter_datetime.strftime("%d/%b/%Y")][o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")]] = o.drug_order.amount_needed
            else
              @other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")][o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")]] = o.drug_order.amount_needed
            end
          else
            @drugs[e.encounter_datetime.strftime("%d/%b/%Y")][o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")]] = o.drug_order.amount_needed
          end
        else
          @other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")][o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")]] = o.drug_order.amount_needed
        end
      }
    } if !@anc_patient.nil?

    render :layout => false
  end

  def tab_detailed_obstetric_history
    @patient = AncConnection::Patient.find(params[:patient_id]) rescue nil

    @anc_patient = ANCService::ANC.new(@patient) rescue nil

    @obstetrics = {}
    search_set = ["YEAR OF BIRTH", "PLACE OF BIRTH", "PREGNANCY", "LABOUR DURATION",
      "METHOD OF DELIVERY", "CONDITION AT BIRTH", "BIRTH WEIGHT", "ALIVE",
      "AGE AT DEATH", "UNITS OF AGE OF CHILD", "PROCEDURE DONE"]
    current_level = 0

    AncConnection::Encounter.find(:all, :conditions => ["encounter_type = ? AND patient_id = ?",
        AncConnection::EncounterType.find_by_name("OBSTETRIC HISTORY").id, @patient.id]).each{|e|
      e.observations.each{|obs|
        concept = obs.concept.concept_names.map(& :name).last rescue nil
        if(!concept.nil?)
          if search_set.include?(concept.upcase)
            if obs.concept_id == (AncConnection::ConceptName.find_by_name("YEAR OF BIRTH").concept_id rescue nil)
              current_level += 1

              @obstetrics[current_level] = {}
            end

            if @obstetrics[current_level]
              @obstetrics[current_level][concept.upcase] = obs.answer_string rescue nil

              if obs.concept_id == (AncConnection::ConceptName.find_by_name("YEAR OF BIRTH").concept_id rescue nil) && obs.answer_string.to_i == 0
                @obstetrics[current_level]["YEAR OF BIRTH"] = "Unknown"
              end
            end

          end
        end
      }
    } if !@patient.nil?

    # raise @obstetrics.to_yaml

    @pregnancies = @anc_patient.active_range if !@patient.nil?

    @range = []

    @pregnancies = @pregnancies[1] rescue []

    @pregnancies.each{|preg|
      @range << preg[0].to_date
    }

    @range = @range.sort

    @range.each{|y|
      current_level += 1
      @obstetrics[current_level] = {}
      @obstetrics[current_level]["YEAR OF BIRTH"] = y.year
      @obstetrics[current_level]["PLACE OF BIRTH"] = "<b>(Here)</b>"
    }

    render :layout => false
  end

  def tab_social_history
    @alcohol = nil
    @smoke = nil
    @nutrition = nil
    
    @patient = AncConnection::Patient.find(params[:patient_id]) rescue nil

    @anc_patient = ANCService::ANC.new(@patient) rescue nil

    @alcohol = AncConnection::Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        AncConnection::ConceptName.find_by_name('Patient currently consumes alcohol').concept_id]).answer_string rescue nil

    @smokes = AncConnection::Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        AncConnection::ConceptName.find_by_name('Patient currently smokes').concept_id]).answer_string rescue nil

    @nutrition = AncConnection::Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        AncConnection::ConceptName.find_by_name('Nutrition status').concept_id]).answer_string rescue nil

    @civil = AncConnection::Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        AncConnection::ConceptName.find_by_name('Civil status').concept_id]).answer_string.titleize rescue nil

    @civil_other = (AncConnection::Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
          @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
          AncConnection::ConceptName.find_by_name('Other Civil Status Comment').concept_id]).answer_string rescue nil) if @civil == "Other"

    @religion = AncConnection::Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        AncConnection::ConceptName.find_by_name('Religion').concept_id]).answer_string.titleize rescue nil

    @religion_other = (AncConnection::Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
          @patient.id, AncConnection::Encounter.find(:all, :conditions => ["patient_id = ? AND encounter_type = ?",
              @patient.id, AncConnection::EncounterType.find_by_name("SOCIAL HISTORY").id]).collect{|e| e.encounter_id},
          AncConnection::ConceptName.find_by_name('Other').concept_id]).answer_string rescue nil) if @religion == "Other"

    render :layout => false
  end

  def general_demographics
    @children = @maternity_patient.children rescue []
    
    render :layout => false
  end

  def birth_report
    @patient = Patient.find(params[:patient_id]) rescue nil
    @person = Patient.find(params[:id] || params[:person_id]) rescue nil
  end

  def birth_report_printable
    @patient = Patient.find(params[:patient_id]) rescue nil
    @person = Patient.find(params[:id] || params[:person_id]) rescue nil
    
    @anc_patient = ANCService::ANC.new(@person) rescue nil

    @mother = Patient.find(@person.mother.person_a) rescue nil

    @anc_mother = ANCService::ANC.new(@mother) rescue nil

    @maternity_mother = MaternityService::Maternity.new(@mother) rescue nil

    @father = Patient.find(@maternity_mother.husband.person_b) rescue nil

    @anc_father = ANCService::ANC.new(@father) rescue nil
    
    facility = CoreService.get_global_property_value("current_facility") rescue ''

    district = CoreService.get_global_property_value("current_district") rescue ''

    patient = Patient.find(params[:patient_id]) rescue nil

    maternity = MaternityService::Maternity.new(patient) rescue nil

    data = maternity.export_person((User.current_user.id rescue 1), facility, district)

    # data = data.delete_blank

    # Due to space limitation, no father demographics on barcode for now
    # data.delete("father")

    # data_w_father = data

    # @qr = RQRCode::QRCode.new(data_w_father.to_json, :size => 40, :level => :h)

    render :layout => false
  end

  def print_note
    # raise request.remote_ip.to_yaml

    location = request.remote_ip rescue ""
    @person    = Patient.find(params[:id]) rescue nil

    if @person
      current_printer = ""

      wards = GlobalProperty.find_by_property("facility.ward.printers").property_value.split(",") rescue []

      printers = wards.each{|ward|
        current_printer = ward.split(":")[1] if ward.split(":")[0].upcase == location
      } rescue []

      t1 = Thread.new{

        Kernel.system "wkhtmltopdf -s A4 http://" +
          request.env["HTTP_HOST"] + "\"/patients/birth_report_printable/" +
          @person.id.to_s + "\" /tmp/output-" + session[:user_id].to_s + ".pdf \n"
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

    redirect_to "/patients/birth_report?person_id=#{@person.id}&patient_id=#{params[:patient_id]}" and return
  end

  def send_birth_report
    facility = CoreService.get_global_property_value("current_facility") rescue ''

    district = CoreService.get_global_property_value("current_district") rescue ''

    patient = Patient.find(params[:id]) rescue nil
    
    maternity = MaternityService::Maternity.new(patient) rescue nil

    data = maternity.export_person(User.current_user.id, facility, district)

    uri = CoreService.get_global_property_value("birth_registration_url") rescue nil

    result = RestClient.post(uri, data)

    if ((result.downcase rescue "") == "baby added") and params[:update].nil?
      BirthReport.create(:person_id => params[:id])
    end

    redirect_to "/patients/birth_report?person_id=#{params[:id]}&patient_id=#{params[:patient_id]}&today=1" and return
  end
  
end

