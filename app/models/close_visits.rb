class CloseVisits < ActiveRecord::Base  
  #to be run from script/console with Visit.close_visits
  #TODO assign a dummy table name here
  set_table_name :visit
  def self.close_visits
    
    failed_visits = Hash.new
    @patients = Patient.all.collect{|p| p.patient_id}
  
    @patients.each do |patient|

      #stats for failed migrations
      failed_attempts = close_patient_visits(patient)
    
      failed_visits[patient] = failed_attempts if failed_attempts > 0

      # return a hash summary of failed records   

    end
    return failed_visits
  end 
  #close all visits for a particular patient using optimal enddate check
  def self.close_patient_visits(patient)
    failed_records = 0
    patient_visits = Visit.find(:all, :conditions => ["patient_id = ?", patient])
    if patient_visits
      patient_visits.each do |visit|
        if visit.end_date.nil?
          last_encounter = visit.encounters.last
          
          closing_datetime_estimate = last_encounter.observations.last.obs_datetime rescue nil

          visit.update_attributes(:end_date => closing_datetime_estimate) if closing_datetime_estimate
          visit.update_attributes(:end_date => last_encounter.date_created) if visit.end_date.nil?
          visit.update_attributes(:end_date => Time.now.strftime("%Y-%m-%d %H:%M:%S")) if visit.end_date.nil?

          failed_records +=1 if visit.end_date.nil?
        end
			
      end
    end
    return failed_records
  end

end

