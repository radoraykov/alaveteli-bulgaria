require 'spec_helper'

describe ReportsController, "when reporting a request when not logged in" do
    it "should only allow logged-in users to report requests" do
        post :create, :url_title => info_requests(:badger_request).url_title

        flash[:notice].should =~ /You need to be logged in/
        response.should redirect_to show_request_path(:url_title => info_requests(:badger_request).url_title)
    end
end

describe ReportsController, "when reporting a request (logged in)" do
    render_views

    before do
        @user = users(:robin_user)
        session[:user_id] = @user.id
    end

    it "should 404 for non-existent requests" do
      lambda {
        post :create, :url_title => "hjksfdhjk_louytu_qqxxx"
      }.should raise_error(ActiveRecord::RecordNotFound)
    end

    it "should mark a request as having been reported" do
        ir = info_requests(:badger_request)
        title = ir.url_title
        ir.attention_requested.should == false

        post :create, :url_title => title
        response.should redirect_to show_request_path(:url_title => title)

        ir.reload
        ir.attention_requested.should == true
        ir.described_state.should == "attention_requested"
    end

    it "should pass on the reason and message" do
        info_request = mock_model(InfoRequest, :url_title => "foo", :attention_requested= => nil, :save! => nil)
        InfoRequest.should_receive(:find_by_url_title!).with("foo").and_return(info_request)
        info_request.should_receive(:report!).with("Not valid request", "It's just not", @user)
        post :create, :url_title => "foo", :reason => "Not valid request", :message => "It's just not"
    end

    it "should not allow a request to be reported twice" do
        title = info_requests(:badger_request).url_title

        post :create, :url_title => title
        response.should redirect_to show_request_url(:url_title => title)

        post :create, :url_title => title
        response.should redirect_to show_request_url(:url_title => title)
        flash[:notice].should =~ /has already been reported/
    end

    it "should send an email from the reporter to admins" do
        ir = info_requests(:badger_request)
        title = ir.url_title
        post :create, :url_title => title
        deliveries = ActionMailer::Base.deliveries
        deliveries.size.should == 1
        mail = deliveries[0]
        mail.subject.should =~ /attention_requested/
        mail.from.should include(@user.email)
        mail.body.should include(@user.name)
    end
end

describe ReportsController, "#new_report_request" do
    let(:info_request) { mock_model(InfoRequest, :url_title => "foo") }
    before :each do
        InfoRequest.should_receive(:find_by_url_title!).with("foo").and_return(info_request)
    end

    context "not logged in" do
        it "should require the user to be logged in" do
            get :new, :url_title => "foo"
            response.should_not render_template("new")
        end
    end

    context "logged in" do
        before :each do
            session[:user_id] = users(:bob_smith_user).id
        end
        it "should show the form" do
            get :new, :url_title => "foo"
            response.should render_template("new")
        end
    end
end


