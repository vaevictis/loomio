require 'spec_helper'

describe Motion do
  subject do
    @motion = Motion.new
    @motion.valid?
    @motion
  end
  it {should have(1).errors_on(:name)}
  it {should have(1).errors_on(:author)}
  it {should have(1).errors_on(:group)}
  it {should have(1).errors_on(:facilitator_id)}

  it "user_has_votes?(user) returns true if the given user has voted on motion" do
    @user = User.make!
    @motion = create_motion(:author => @user)
    @vote = Vote.make(:position => "yes")
    @vote.user = @user
    @vote.motion = @motion
    @vote.save!
    @motion.user_has_voted?(@user).should == true
  end

  context "motion created" do
    it "sends email to group members if email notifications are enabled (default)" do
      pending "this test is weird"
      group = Group.make!
      group.add_member!(User.make!)
      group.add_member!(User.make!)
      # Do not send email to author, so subtract one from total emails sent
      MotionMailer.should_receive(:new_motion_created)
        .exactly(group.users.count - 1).times
        .with(kind_of(Motion), kind_of("")).and_return(stub(deliver: true))
      # NOTE (Jon): this should actually be create_motion(group: group), but that fails
      @motion = create_motion
    end

    it "does not send email to group members if email notifications are disabled" do
      group = Group.make
      group.email_new_motion = false
      group.save
      group.add_member!(User.make!)
      group.add_member!(User.make!)
      MotionMailer.should_not_receive(:new_motion_created)
      @motion = create_motion(group: group)
    end
  end

  it "cannot have invalid phases" do
    @motion = create_motion
    @motion.phase = 'bad'
    @motion.should_not be_valid
  end

  it "it can remain un-blocked" do
    @motion = create_motion
    user1 = User.make
    user1.save
    @motion.group.add_member!(user1)
    vote = Vote.new(position: 'yes')
    vote.motion = @motion
    vote.user = user1
    vote.save
    @motion.blocked?.should == false
  end

  it "it can be blocked" do
    @motion = create_motion
    user1 = User.make
    user1.save
    @motion.group.add_member!(user1)
    vote = Vote.new(position: 'block')
    vote.motion = @motion
    vote.user = user1
    vote.save
    @motion.blocked?.should == true
  end

  it "can have a close date" do
    @motion = create_motion
    @motion.close_date = '2012-12-12'
    @motion.close_date.should == Date.parse('2012-12-12')
    @motion.should be_valid
  end

  it "can have a discussion link" do
    @motion = create_motion
    @motion.discussion_url = "http://our-discussion.com"
    @motion.should be_valid
  end

  it "can have a discussion" do
    @motion = create_motion
    @motion.save
    @motion.discussion.should_not be_nil
  end

  it "can update vote_activity" do
    @motion = create_motion
    @motion.vote_activity = 3
    @motion.update_vote_activity
    @motion.vote_activity.should == 4
  end

  it "can update discussion_activity" do
    @motion = create_motion
    @motion.discussion.activity = 3
    @motion.update_discussion_activity
    @motion.discussion.activity.should == 4
  end

  context "moving motion to new group" do
    before do
      @new_group = Group.make!
      @motion = create_motion
      @motion.move_to_group @new_group
      @motion.save
    end

    it "changes motion group_id to new group" do
      @motion.group.should == @new_group
    end

    it "changes motion discussion_id to new group" do
      @motion.discussion.group.should == @new_group
    end
  end

  context "destroying a motion" do
    before do
      @motion = create_motion
      @vote = Vote.create(position: "no", motion: @motion, user: @motion.author)
      @comment = @motion.discussion.add_comment(@motion.author, "hello")
      @motion.author.update_motion_read_log(@motion)
      @motion.destroy
    end

    it "deletes associated votes" do
      Vote.first.should == nil
    end

    it "deletes associated motion read logs" do
      MotionReadLog.first.should == nil
    end

  end

  context "closed motion" do
    before :each do
      user1 = User.make
      user1.save
      user2 = User.make
      user2.save
      @user3 = User.make
      @user3.save
      @motion = create_motion(author: user1, facilitator: user1)
      @motion.group.add_member!(user1)
      @motion.group.add_member!(user2)
      @motion.group.add_member!(@user3)
      vote1 = Vote.new(position: 'yes')
      vote1.motion = @motion
      vote1.user = user1
      vote1.save
      vote2 = Vote.new(position: 'no')
      vote2.motion = @motion
      vote2.user = user2
      vote2.save
      @motion.close_voting!
    end

    it "stores users who did not vote" do
      DidNotVote.first.user.should == @user3
    end

    it "no_vote_count should return number of users who did not vote" do
      @motion.no_vote_count.should == 1
    end

    it "users_who_did_not_vote should return users who did not vote" do
      @motion.users_who_did_not_vote.should include(@user3)
    end

    it "reopening motion deletes did_not_vote records" do
      @motion.open_voting
      DidNotVote.all.count.should == 0
    end
  end

  context "open motion" do
    before :each do
      @user1 = User.make
      @user1.save
      @group = Group.make
      @group.save
      @group.add_member! @user1
      @motion1 = Motion.new(name: "hi", facilitator_id: @user1, group: @group, phase: "voting")
      @motion1.author = @user1
      @motion1.save!
    end

    context "no_vote_count" do
      it "should return number of users who have not voted yet" do
        @motion1.no_vote_count.should == 1
      end

      it "should not change if users vote multiple times" do
        pending "this test is failing for some reason, but the functionality works everywhere else"
        user2 = User.make
        user2.save
        @group.add_member! user2
        Vote.create!(motion: @motion1, position: "yes", user: @user1)
        Vote.create!(motion: @motion1, position: "no", user: @user1)
        Vote.create!(motion: @motion1, position: "abstain", user: @user1)
        @motion1.reload
        @motion1.no_vote_count.should == 1
      end
    end

    it "users_who_did_not_vote should return users who did not vote" do
      @motion1.users_who_did_not_vote.should include(@user1)
    end

  end
end
