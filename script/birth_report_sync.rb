
class BirthReportSync
  def self.send_failed_birth_reports

    uri = CoreService.get_global_property_value("birth_registration_url")
  
    @birth_reports = BirthReport.find_by_sql("SELECT * FROM birth_report WHERE acknowledged IS NULL OR sent_by IS NULL")
    
    puts "........................#{@birth_reports.length} birth reports found"
    puts "........................Processing"

    @facility = CoreService.get_global_property_value("current_facility") 

    @district = CoreService.get_global_property_value("current_district") 
    
    #check for provider details for each birth report
    failed_attempts = 0
    sent = 0
    @birth_reports.each do |br|

      @baby = Patient.find(br.person_id) rescue nil
      next if @baby.blank?
      @anc_patient = ANCService::ANC.new(@baby)

      hospital_date = @anc_patient.get_attribute("Hospital Date")
      if hospital_date.blank?
        #set hospital_date
        @likely_date = br.date_created.to_date rescue nil
        @anc_patient.set_attribute("Hospital Date", @likely_date) if @likely_date.present?
      end
      
      health_center = @anc_patient.get_attribute("Health Center")
      if health_center.blank?
        #set health center
        @anc_patient.set_attribute("Health Center", @facility) if @facility.present?
      end
      
      health_district = @anc_patient.get_attribute("Health District")
      if health_district.blank?
        #set health district
        @anc_patient.set_attribute("Health District", @district)
      end
      
      provider_title = @anc_patient.get_attribute("Provider Title")
      if provider_title.blank?
        #how do we go about this?
        @hacked = BirthReport.find_by_sql("SELECT * FROM birth_report WHERE created_by = #{br.created_by} AND acknowledged IS NOT NULL
          ORDER BY date_created DESC LIMIT 1").last rescue nil
        @hacked_baby = Patient.find(@hacked.person_id)
        @hacked_anc_baby =  ANCService::ANC.new(@hacked_baby) rescue nil
        @hacked_provider_title = @hacked_anc_baby.get_attribute("Provider Title") rescue nil
        @anc_patient.set_attribute("Provider Title", @hacked_provider_title) if @hacked_provider.present?
      end
      
      provider_name = @anc_patient.get_attribute("Provider Name")
      if provider_name.blank?
        #set provider name
        @name = User.find(br.created_by).name rescue nil
        @anc_patient.set_attribute("Provider Name", @name)
      end

      maternity = MaternityService::Maternity.new(@baby) rescue nil

      user_id = User.find_by_username("admin").id

      data = maternity.export_person(user_id, @facility, @district)

      uri = CoreService.get_global_property_value("birth_registration_url") rescue nil

      result = RestClient.post(uri, data) rescue "birth report couldnt be sent"

      if result.downcase == "baby added"
        #update birth report attributes
        
        br.update_attributes(:sent_by => br.created_by,
          :date_updated => Time.now,
          :acknowledged => Time.now)
        
        sent += 1

        puts "Finished sending #{br.person_id}"
        
      else

        failed_attempts += 1
        puts "Failed to send #{br.person_id}"
      end
    
    end
  end

  start = Time.now
  puts "Birth Reports Sync Started at #{start}"
 
  send_failed_birth_reports
 
  puts "Started at: #{start} - Finished at:#{Time.now()}"
 
end
