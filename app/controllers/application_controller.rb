class ApplicationController < ActionController::Base
  include AuthenticatedSystem

  helper :all
  filter_parameter_logging :password
  before_filter :login_required, :except => ['login', 'logout','demographics', 'add_update_property',
    'observations_printable', 'cohort_print', 'print_cohort', 'birth_report', 'issue_birth_report', 'issue_baby_ids', 'report', 'delivered_patients', 'diagnoses_report', 'birth_report_printable', 'birth_report', 'death_report_printable']
  before_filter :location_required, :except => ['login', 'logout', 'birth_cohort', 'location','demographics',
    'add_update_property', 'observations_printable', 'diagnoses_report', 'issue_birth_report', 'death_report_printable' , 'delivered_patients', 'issue_baby_ids', 'cohort_print','report','print_cohort', 'birth_report_printable', 'birth_report']
  
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
    current_visit_encounters = patient.current_visit.encounters.active.find(:all, :include => [:type]).map{|e| e.type.name} rescue []
    # Registration clerk needs to do registration if it hasn't happened yet
    return "/encounters/new/registration?patient_id=#{patient.id}" if !current_visit_encounters.include?("REGISTRATION") || patient.current_visit.nil? || patient.current_visit.end_date != nil
   
    unless params[:action] == "new"
      return "/patients/show/#{patient.id}?skip_check=true"
    else
      return "/patients/show/#{patient.id}"
    end
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
