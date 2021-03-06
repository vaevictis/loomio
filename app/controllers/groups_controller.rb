class GroupsController < GroupBaseController
  load_and_authorize_resource except: :show
  before_filter :check_group_read_permissions, :only => :show

  def create
    @group = Group.new(params[:group])
    if @group.save
      @group.add_admin! current_user
      flash[:notice] = "Group created successfully."
      redirect_to @group
    else
      redirect_to :back
    end
  end

  # CUSTOM CONTROLLER ACTIONS

  def add_subgroup
    @parent = Group.find(params[:group_id])
    @subgroup = Group.new(:parent => @parent)
    @subgroup.viewable_by = @parent.viewable_by
    @subgroup.members_invitable_by = @parent.members_invitable_by
  end

  def add_members
    params.each_key do |key|
      if key =~ /user_/
        user = User.find(key[5..-1])
        group.add_member!(user)
      end
    end
    flash[:notice] = "Members added to group."
    redirect_to group_url(group)
  end

  def request_membership
    if resource.users.include? current_user
      redirect_to group_url(resource)
    else
      @membership = Membership.new
    end
  end

  private

    def group
      resource
    end
end
