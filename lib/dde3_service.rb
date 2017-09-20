 require 'rest-client'

 module DDE3Service

  def self.dde3_configs
    YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env]
  end

  def self.dde3_url
    dde3_configs = self.dde3_configs
    protocol = dde3_configs['secure_connection'].to_s == 'true' ? 'https' : 'http'
    "#{protocol}://#{dde3_configs['dde_server']}"
  end

  def self.dde3_url_with_auth
    dde3_configs = self.dde3_configs
    protocol = dde3_configs['secure_connection'].to_s == 'true' ? 'https' : 'http'
    "#{protocol}://#{dde3_configs['dde_username']}:#{dde3_configs['dde_password']}@#{dde3_configs['dde_server']}"
  end

  def self.authenticate
    dde3_configs = self.dde3_configs
     url = "#{self.dde3_url}/v1/authenticate"

     res = JSON.parse(RestClient.post(url,
     	      {'username' => dde3_configs['dde_username'],
     	       'password' => dde3_configs['dde_password']}.to_json, 
     	       :content_type => 'application/json'))

     token = nil
     if (res.present? && res['status'] && res['status'] == 200)
     	token = res['data']['token']
     end
              
     File.open("#{Rails.root}/tmp/token", 'w') {|f| f.write(token) } if token.present?
      token

     
  end

  def self.authenticate_by_admin
    dde3_configs = self.dde3_configs
    url = "#{self.dde3_url}/v1/authenticate"

    params = {'username' => 'admin', 'password' => 'admin'}

    res = JSON.parse(RestClient.post(url, params.to_json, :content_type => 'application/json'))
    token = nil
    if (res.present? && res['status'] && res['status'] == 200)
      token = res['data']['token']
    end

    token
  end


  def self.add_user(token)
    dde3_configs = self.dde3_configs
    url = "#{self.dde3_url}/v1/add_user"
    url = url.gsub(/\/\//, "//admin:admin@")
    response = RestClient.put(url,{
                  "username" => dde3_configs["dde_username"],  "password" => dde3_configs["dde_password"],
                  "application" => dde3_configs["application_name"], "site_code" => dde3_configs["site_code"],
                  "description" => "Maternity Clinic"
              }.to_json, :content_type => 'application/json')

      if response['status'] == 201
        return response['data']
      else
        return false
      end
  end

 def self.token
    self.validate_token(File.read("#{Rails.root}/tmp/token"))
  end

  def self.validate_token(token)
    url = "#{self.dde3_url}/v1/authenticated/#{token}"
    response = nil
    response = JSON.parse(RestClient.get(url)) rescue nil if !token.blank?

    if !response.blank? && response['status'] == 200
      return token
    else
      return self.authenticate
    end
  end

def self.search_by_identifier(npid)
      
    url = "#{self.dde3_url}/v1/search_by_identifier/#{npid.strip}/#{self.token}"
    response = JSON.parse(RestClient.get(url)) rescue nil

    if response.present? && [200, 204].include?(response['status'])
      return response['data']['hits']
    else
      return []
    end

end

def self.search_from_dde3(params)
    return [] if params['given_name'].blank? ||  params['family_name'].blank? ||
        params['gender'].blank?


    url = "#{self.dde3_url_with_auth}/v1/search_by_name_and_gender"
    params = {'given_name' => params['given_name'],
              'family_name' => params['family_name'],
              'gender' => ({'F' => 'Female', 'M' => 'Male'}[params['gender']] || params['gender'])
    }

    response = JSON.parse(RestClient.post(url, params.to_json, :content_type => 'application/json')) rescue nil

    if response.present?
      return response['data']['hits']
    else
      return false
    end
  end


def self.search_all_by_identifier(npid)
    identifier = npid.gsub(/\-/, '').strip
    people = PatientIdentifier.find_all_by_identifier_and_identifier_type(identifier, 3).map{|id|
      id.patient.person
    } unless identifier.blank?

    return people unless people.blank?

    remote = self.search_by_identifier(identifier)
    return [] if remote.blank?
    return "found duplicate identifiers" if remote.count > 1

    p = nil
    remote.each do |x|
      next if x['gender'] == 'M'
      p = x
      break
    end

    p = remote.first if p.blank?

    return [] if p.blank?

    passed_national_id = p["npid"]

    unless passed_national_id.blank?
      patient = PatientIdentifier.find(:first,
                                       :conditions =>["voided = 0 AND identifier = ? AND identifier_type = 3",passed_national_id]).patient rescue nil
      return [patient.person] unless patient.blank?
    end


    birthdate_year = p["birthdate"].to_date.year
    birthdate_month = p["birthdate"].to_date.month
    birthdate_day = p["birthdate"].to_date.day
    birthdate_estimated = p["birthdate_estimated"]
    gender = p["gender"].match(/F/i) ? "Female" : "Male"
    p['attributes'] = {} if p['attributes'].blank?

    passed = {
        "person"  =>{
                   "occupation"        =>p['attributes']["occupation"],
                   "age_estimate"      => birthdate_estimated,
                   "cell_phone_number" =>p["attributes"]["cell_phone_number"],
                   "citizenship"       => p['attributes']["citizenship"],
                   "birth_month"       => birthdate_month ,
                   "addresses"         =>{"address1"=>p['addresses']["current_residence"],
                                         'township_division' => p['current_ta'],
                                         "address2"=>p['addresses']["home_district"],
                                         "city_village"=>p['addresses']["current_village"],
                                         "state_province"=>p['addresses']["current_district"],
                                         "neighborhood_cell"=>p['addresses']["home_village"],
                                         "county_district"=>p['addresses']["home_ta"]},
                   "gender"            => gender ,
                   "patient"           =>{"identifiers"=>{"National id" => p["npid"]}},
                   "birth_day"         =>birthdate_day,
                   "names"             =>{"family_name"=>p['names']["family_name"],
                                         "given_name"=>p['names']["given_name"],
                                         "middle_name"=> (p['names']["middle_name"] || "")},
                   "birth_year"        =>birthdate_year
                      },
        "filter_district"=>"",
        "filter"=>{"region"=>"",
                   "t_a"=>""},
        "relation"=>""
    }

    passed["person"].merge!("identifiers" => {"National id" => passed_national_id})
    result = [p]
    result = [PatientService.create_from_form(passed["person"])] if gender == 'Female'
    return result
  

end

def self.update_local_demographics(data)
    data
  end

def self.push_to_dde3(patient_bean)
  
   
    from_dde3 = self.search_by_identifier(patient_bean.national_id_with_dashes)
              
    if from_dde3.length > 0 && !patient_bean.national_id_with_dashes.strip.match(/^P\d+$/)
      return self.update_local_demographics(from_dde3[0])
    else
      result = {
          "family_name"=> patient_bean.last_name,
          "given_name"=> patient_bean.first_name,
          "gender"=> patient_bean.sex,
          "attributes"=> {
              "occupation"=> (patient_bean.occupation rescue ""),
              "cell_phone_number"=> (patient_bean.cell_phone_number rescue ""),
              "citizenship" => (patient_bean.citizenship rescue "")
          },
          "birthdate" => (Person.find(patient_bean.person_id).birthdate.to_date.strftime('%Y-%m-%d') rescue nil),
          "birthdate_estimated" => (patient_bean.birthdate_estimated.to_s == '0' ? false : true),
          "identifiers"=> {
              'Old Identification Number' => patient_bean.national_id_with_dashes
          },
          "current_residence"=> patient_bean.landmark,
          "current_village"=> patient_bean.current_residence,
          "current_district"=>  patient_bean.current_district,
          "home_village"=> patient_bean.home_village,
          "home_ta"=> patient_bean.traditional_authority,
          "home_district"=> patient_bean.home_district
      }

      result['home_district'] = 'Other' if result['home_district'].blank?

      (result['attributes'] || {}).each do |k, v|
        if v.blank? || v.match(/^N\/A$|^null$|^undefined$|^nil$/i)
          result['attributes'].delete(k)  unless [true, false].include?(v)
        end
      end

      (result['identifiers'] || {}).each do |k, v|
        if v.blank? || v.match(/^N\/A$|^null$|^undefined$|^nil$/i)
          result['identifiers'].delete(k)  unless [true, false].include?(v)
        end
      end

      result.each do |k, v|
        if v.blank? || v.to_s.match(/^null$|^undefined$|^nil$/i)
          result.delete(k) unless [true, false].include?(v)
        end
      end

      data = self.create_from_dde3(result)

     

      if data.present? && data['return_path']
        data = self.force_create_from_dde3(result, data['return_path'])
      end

      if !data.blank?
        npid_type = PatientIdentifierType.find_by_name('National id').id
        npid = PatientIdentifier.find_by_identifier_and_identifier_type_and_patient_id(patient_bean.national_id_with_dashes,
                npid_type, patient_bean.patient_id)
          
        npid.update_attributes(
            :voided => true,
            :voided_by => User.id,
            :void_reason => 'Reassigned NPID',
            :date_voided => Time.now
        )
        PatientIdentifier.create(
            :patient_id => npid.patient_id,
            :creator => User.id,
            :identifier => npid.identifier,
            :identifier_type => PatientIdentifierType.find_by_name('Old Identification Number').id
        )

        PatientIdentifier.create(
            :patient_id => npid.patient_id,
            :creator => User.id,
            :identifier =>  data['npid'],
            :identifier_type => npid_type
        )
      end

      data
    end
  end

  def self.force_create_from_dde3(params, path)
    url = "#{self.dde3_url}#{path}"
    params['token'] = self.token
    params.delete_if{|k,v| ['npid', 'return_path'].include?(k)}

    data = {}
    RestClient.put(url, params.to_json, :content_type => 'application/json'){|response, request, result|
      response = JSON.parse(response) rescue response
      if response['status'] == 201
        data = response['data']
      end
    }
    data
  end


def self.create_from_dde3(params)
    url = "#{self.dde3_url_with_auth}/v1/add_patient"
    params['token'] = self.token
    data = {}

    RestClient.put(url, params.to_json, :content_type => 'application/json'){|response, request, result|
       response = JSON.parse(response) rescue response

      if response['status'] == 201
         data = response['data']
      elsif response['status'] == 409
        data = response
      end
    }
    data
  end

end





