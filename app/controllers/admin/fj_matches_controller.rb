class Admin::FjMatchesController <  Admin::BaseController
  def index
    sql=''


    params[:name].present? &&
        sql="name like '%#{params[:name]}%'"

    @matches=FjMatch.where(' match_id NOT IN (SELECT match_id FROM matchs where match_id is not null)')
                    .where(sql).order(:time).page(params[:page]).per(10)
  end

  def add_match
    fj_match=FjMatch.find(params[:id])
    fj_match.add_to_match
    respond_to do |format|
      format.html {redirect_to admin_fj_matches_path}
    end
  end
end