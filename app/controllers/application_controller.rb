class ApplicationController < ActionController::Base
  include AuthenticatedSystem

  helper :all
  filter_parameter_logging :password
  before_filter :login_required, :except => ['login', 'logout','demographics', 'add_update_property',
    'observations_printable', 'cohort_print', 'print_cohort', 'report', 'diagnoses_report', 'birth_report_printable', 'birth_report']
  before_filter :location_required, :except => ['login', 'logout', 'location','demographics',
    'add_update_property', 'observations_printable', 'diagnoses_report', 'cohort_print','report','print_cohort', 'birth_report_printable', 'birth_report']
  
  def rescue_action_in_public(exception)
    @message = exception.message
    @backtrace = exception.backtrace.join("\n") unless exception.nil?
    render :file => "#{RAILS_ROOT}/app/views/errors/error.rhtml", :layout=> false, :status => 404
  end if RAILS_ENV == 'development' || RAILS_ENV == 'test'

  def rescue_action(exception)
    @message = exception.message
    @backtrace = exception.backtrace.join("\n") unless exception.nil?
    render :file => "#{RAILS_ROOT}/app/views/errors/error.rhtml", :layout=> false, :status => 404
  end if RAILS_ENV == 'production'
  #test push

  def next_task(patient)
    patient_encounters = patient.encounters.active.find(:all, :include => [:type]).map{|e|
      e.type.name.upcase if (Date.today == e.date_created)}.uniq rescue []

    if (params["encounter"]["encounter_type_name"].upcase rescue "") == "UPDATE OUTCOME"
      params["observations"].each do |o|
        if !o["value_coded_or_text"].nil? \
            and ["DISCHARGED", "ABSCONDED", "PATIENT DIED"].include?(o["value_coded_or_text"].upcase)
          return "/people"
        end

      end
    end
    #check current registration
    unless session[:skip_reg]
      already_registered = (patient.encounters.active.find(:all, :include => [:type]).map{|e|
          e.type.name.upcase if (Date.today == e.date_created.to_date)}.uniq rescue []).include?("REGISTRATION")
      
      #check if registration happened some days before for admitted patients
      last_admission_date = PatientState.find(:last, :conditions => ["patient_program_id = ?",
          Program.find_by_name("MATERNITY PROGRAM").id],
        :order => ["date_created"]).program_workflow_state.map{|s|
        s.date_created if ["ADMITTED"].include?(ConceptName.find_by_concept_id(s.concept_id).name.upcase)}.last rescue Date.today if already_registered == false
      already_registered = last_admission_date ? ((patient.encounters.active.find(:all, :include => [:type]).map{|e|
            e.type.name.upcase if (last_admission_date.to_date <= e.date_created.to_date)}.uniq rescue []).include?("REGISTRATION"))  : (false)
    
      # Registration clerk needs to do registration if it hasn't happened yet
      return "/encounters/new/registration?patient_id=#{patient.id}" if already_registered == false
    end
    return "/patients/show/#{patient.id}" 
  end

  def print_and_redirect(print_url, redirect_url, message = "Printing, please wait...")
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    render :template => 'print/print', :layout => nil
  end

  def next_discharge_task(patient)
    outcome = patient.current_outcome

    return "/encounters/new/outcome?patient_id=#{patient.id}" if outcome.nil?

    return "/patients/hiv_status?patient_id=#{patient.id}" if session[:hiv_status_updated] == false && ['DEAD', 'ALIVE', 'ABSCONDED', 'TRANSFERRED'].include?(outcome) && !patient.current_visit.encounters.active.map{|enc| enc.name}.include?('UPDATE HIV STATUS')

    return "/encounters/diagnoses_index?patient_id=#{patient.id}" if  session[:diagnosis_done] == false && ['DEAD','ALIVE', 'ABSCONDED', 'TRANSFERRED'].include?(outcome)

    return "/prescriptions/?patient_id=#{patient.id}" if session[:prescribed] == false && ['ALIVE', 'ABSCONDED', 'TRANSFERRED'].include?(outcome)  && !patient.current_diagnoses.empty?
    
    session[:auto_load_forms] = false
    return "/patients/show/#{patient.id}" 

  end

  def next_admit_task(patient)
    
    return "/encounters/new/admit_patient?patient_id=#{patient.id}" if  session[:diagnosis_done] == false && !patient.admitted_to_ward
    return "/encounters/diagnoses_index?patient_id=#{patient.id}" if  session[:diagnosis_done] == false
    session[:auto_load_forms] = false
    return "/patients/show/#{patient.id}" 

  end

  def close_visit
    return "/people"
  end

  def send_label(label_data)
    send_data(
      label_data,
      :type=>"application/label; charset=utf-8",
      :stream => false,
      :filename => "#{Time.now.to_i}#{rand(100)}.lbl",
      :disposition => "inline"
    )
  end

  def create_from_dde_server
    CoreService.get_global_property_value('create.from.dde.server').to_s == "true" rescue false
  end

  def link_to_anc
    CoreService.get_global_property_value('link.to.anc').to_s == "true" rescue false
  end

  def create_from_remote
    CoreService.get_global_property_value('create.from.remote').to_s == "true" rescue false
  end

  private

  def find_patient
    @patient = Patient.find(params[:patient_id] || session[:patient_id] || params[:id]) rescue nil
    @anc_patient = ANCService::ANC.new(@patient) rescue nil
    @maternity_patient = MaternityService::Maternity.new(@patient) rescue nil
  end
  
end
