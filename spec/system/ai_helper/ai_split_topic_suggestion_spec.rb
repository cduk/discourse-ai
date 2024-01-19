# frozen_string_literal: true

RSpec.describe "AI Post helper", type: :system, js: true do
  fab!(:user) { Fabricate(:admin) }
  fab!(:non_member_group) { Fabricate(:group) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:category) { Fabricate(:category) }
  fab!(:category_2) { Fabricate(:category) }
  fab!(:post) do
    Fabricate(
      :post,
      topic: topic,
      raw:
        "I like to eat pie. It is a very good dessert. Some people are wasteful by throwing pie at others but I do not do that. I always eat the pie.",
    )
  end
  fab!(:post_2) do
    Fabricate(
      :post,
      topic: topic,
      raw: "I prefer to eat croissants. They are my personal favorite dessert!",
    )
  end
  fab!(:post_3) do
    Fabricate(
      :post,
      topic: topic,
      raw: "I disagree with both of you, I think cake is the best dessert.",
    )
  end
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:suggestion_menu) { PageObjects::Components::AiSplitTopicSuggester.new }
  fab!(:video) { Fabricate(:tag) }
  fab!(:music) { Fabricate(:tag) }
  fab!(:cloud) { Fabricate(:tag) }
  fab!(:feedback) { Fabricate(:tag) }
  fab!(:review) { Fabricate(:tag) }

  before do
    Group.find_by(id: Group::AUTO_GROUPS[:admins]).add(user)
    SiteSetting.composer_ai_helper_enabled = true
    sign_in(user)
  end

  def open_move_topic_modal
    topic_page.visit_topic(topic)
    find(".topic-timeline .toggle-admin-menu").click
    find(".topic-admin-multi-select .btn").click
    find("#post_2 .select-posts .select-below").click
    find(".move-to-topic").click
  end

  describe "moving posts to a new topic" do
    context "when suggesting titles with AI title suggester" do
      let(:mode) { CompletionPrompt::GENERATE_TITLES }
      let(:titles) do
        "<item>Pie: A delicious dessert</item><item>Cake is the best!</item><item>Croissants are delightful</item><item>Some great desserts</item><item>What is the best dessert?</item>"
      end

      it "opens a menu with title suggestions" do
        open_move_topic_modal
        DiscourseAi::Completions::Llm.with_prepared_responses([titles]) do
          suggestion_menu.click_suggest_titles_button
          wait_for { suggestion_menu.has_dropdown? }
          expect(suggestion_menu).to have_dropdown
        end
      end

      it "replaces the title input with the selected title" do
        open_move_topic_modal
        DiscourseAi::Completions::Llm.with_prepared_responses([titles]) do
          suggestion_menu.click_suggest_titles_button
          wait_for { suggestion_menu.has_dropdown? }
          suggestion_menu.select_suggestion_by_value(1)
          expected_title = "Cake is the best!"
          expect(find("#split-topic-name").value).to eq(expected_title)
        end
      end
    end

    context "when suggesting categories with AI category suggester" do
      before { SiteSetting.ai_embeddings_enabled = true }

      skip "TODO: Category suggester only loading one category in test" do
        it "updates the category with the suggested category" do
          response =
            Category
              .take(3)
              .pluck(:name)
              .map { |s| { name: s, score: rand(0.0...45.0) } }
              .sort { |h| h[:score] }
          DiscourseAi::AiHelper::SemanticCategorizer
            .any_instance
            .stubs(:categories)
            .returns(response)

          open_move_topic_modal
          suggestion_menu.click_suggest_category_button
          wait_for { suggestion_menu.has_dropdown? }
          suggestion = category.name
          suggestion_menu.select_suggestion_by_name(suggestion)
          category_selector = page.find(".category-chooser summary")

          expect(category_selector["data-name"]).to eq(suggestion)
        end
      end
    end

    context "when suggesting tags with AI tag suggester" do
      before { SiteSetting.ai_embeddings_enabled = true }

      it "update the tag with the suggested tag" do
        response =
          Tag
            .take(5)
            .pluck(:name)
            .map { |s| { name: s, score: rand(0.0...45.0) } }
            .sort { |h| h[:score] }
        DiscourseAi::AiHelper::SemanticCategorizer.any_instance.stubs(:tags).returns(response)

        open_move_topic_modal
        suggestion_menu.click_suggest_tags_button
        wait_for { suggestion_menu.has_dropdown? }

        suggestion = suggestion_menu.suggestion_name(0)
        suggestion_menu.select_suggestion_by_value(0)
        tag_selector = page.find(".tag-chooser summary")

        expect(tag_selector["data-name"]).to eq(suggestion)
      end
    end
  end
end
