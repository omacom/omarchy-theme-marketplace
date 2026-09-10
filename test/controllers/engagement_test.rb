require "test_helper"

class EngagementTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github", uid: "4242",
      info: { nickname: "HalmyLyseas", name: "Halmy", image: "https://avatars.githubusercontent.com/u/4242" }
    )
    Rails.cache.clear
  end

  def sign_in
    post "/auth/github"
    follow_redirect! # OmniAuth test mode → callback
    assert_response :redirect
  end

  test "login page and sign-in flow" do
    get login_path
    assert_response :success
    assert_select "form[action='/auth/github']", count: 0
    assert_select "button[disabled]", /Continue with GitHub/

    sign_in
    follow_redirect!
    assert_select "header a[href=?]", me_path
    assert_equal 1, User.count
    assert_equal "HalmyLyseas", User.last.login

    delete logout_path
    follow_redirect!
    assert_select "header a[href=?]", me_path, count: 0
    assert_equal 0, Session.count
  end

  test "return_to survives the sign-in round trip" do
    get me_path
    assert_redirected_to login_path
    sign_in
    assert_redirected_to me_path
  end

  test "likes are hidden in the UI for v1" do
    get root_path(filter: "all")
    assert_select "form[id^=like-]", count: 0
    get theme_path("nujabes")
    assert_select "form[id^=like-]", count: 0
    get root_path(filter: "all", sort: "likes")
    assert_select "select#gallery-sort option[value=likes]", count: 0
  end

  test "liking (backend only) requires login and toggles" do
    post theme_like_path("nujabes"), as: :turbo_stream
    assert_redirected_to login_path

    sign_in
    post theme_like_path("nujabes"), as: :turbo_stream
    assert_response :success
    assert_match %r{turbo-stream action="replace" target="like-nujabes"}, response.body
    assert_select "form#like-nujabes button[aria-pressed=true]"
    assert_equal 1, Like.count

    assert_equal 1, User.last.likes.count

    delete theme_like_path("nujabes"), as: :turbo_stream
    assert_response :success
    assert_equal 0, Like.count
  end

  test "me page lists liked and own themes" do
    sign_in
    post theme_like_path("nujabes")
    get me_path
    assert_response :success
    assert_select "h1", "Halmy"
    assert_select "a[href=?]", theme_path("nujabes"), minimum: 1
  end

  test "copying the install command is counted per day and feeds trending" do
    post theme_copied_path("nujabes"), headers: { "Accept" => "application/json" }
    assert_response :success
    assert_equal 1, response.parsed_body["copies"]
    post theme_copied_path("nujabes")
    assert_equal 2, CommandCopy.total_for("nujabes")
    assert_equal 1, CommandCopy.count

    post theme_copied_path("no-such-theme")
    assert_response :not_found

    get theme_path("nujabes")
    assert_select "dd", "2 times"
    get root_path(filter: "all", sort: "trending")
    assert_response :success
    assert_select "[data-slot=card]:first-of-type a[href=?]", theme_path("nujabes")
  end

  test "report a problem points at the artist's issue tracker" do
    get theme_path("nujabes")
    assert_select "a[href$='/issues']", /Report a problem/
  end
end
