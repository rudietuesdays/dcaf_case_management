require 'test_helper'

class CallListTest < ActionDispatch::IntegrationTest
  before do
    Capybara.current_driver = :poltergeist
    @patient = create :patient, name: 'Susan Everyteen'
    @pregnancy = create :pregnancy, patient: @patient
    @patient_2 = create :patient, name: 'Thorny'
    @pregnancy_2 = create :pregnancy, patient: @patient_2
    @va_patient = create :patient, name: 'James Hetfield', line: 'VA'
    @va_pregnancy = create :pregnancy, patient: @va_patient
    @user = create :user
    [@patient_2, @va_patient].each { |pt| @user.add_patient pt }
    log_in_as @user
    add_to_call_list @patient.name
  end

  after do
    Capybara.use_default_driver
  end

  describe 'populating call list' do
    it 'should add people to the call list roll' do
      within :css, '#call_list_content' do
        assert has_text? @patient.name
        assert has_text? @patient_2.name
        assert has_link? 'Remove', count: 2
      end
    end

    it 'should scope the call list to a particular line' do
      within :css, '#call_list_content' do
        assert has_no_text? @va_patient.name
      end
    end

    it 'should let you remove people from the call list roll' do
      find('a', text: 'Remove').click
      within :css, '#call_list_content' do
        assert has_no_text? @patient.name
      end
    end
  end

  describe 'call list persistence between multiple users' do
    before do
      @user_2 = create :user
    end

    it 'should allow a call to be on two users call lists' do
      sign_out
      log_in_as @user_2
      add_to_call_list @patient.name
      within :css, '#call_list_content' do
        assert has_text? @patient.name
      end
      sign_out

      log_in_as @user
      within :css, '#call_list_content' do
        assert has_text? @patient.name
      end
    end
  end

  describe 'completed calls section' do
    before do
      within :css, '#call_list_content' do
        find("a[href='#call-#{@patient.primary_phone_display}']").click
      end
      find('a', text: 'I left a voicemail for the patient').click
      visit authenticated_root_path
      wait_for_element 'Your completed calls'
    end

    it 'should add a call to completed when a call was made within 8 hrs' do
      within :css, '#completed_calls_content' do
        assert has_text? @patient.name
      end

      within :css, '#call_list_content' do
        assert has_no_text? @patient.name
      end
    end

    it 'should time a call out after 8 hours' do
      Timecop.freeze(9.hours.from_now) do
        log_in_as @user
        wait_for_element 'Your completed calls'

        within :css, '#completed_calls_content' do
          assert has_no_text? @patient.name
        end

        within :css, '#call_list_content' do
          assert has_text? @patient.name
        end
      end
    end
  end

  private

  def add_to_call_list(patient_name)
    fill_in 'search', with: patient_name
    click_button 'Search'
    find('a', text: 'Add').click
  end
end
