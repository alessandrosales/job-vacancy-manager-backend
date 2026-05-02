# frozen_string_literal: true

# Shared examples for `index` actions wrapped by Api::V1::Paginatable.
#
# Usage in a request spec:
#
#   it_behaves_like "paginated index", path: "/api/v1/skills" do
#     let(:authorization_header) { "Bearer #{User::JwtIssuer.encode(owner)}" }
#     let!(:owner) { User.create!(...) }
#     before { 3.times { |i| owner.skills.create!(name: "S#{i}") } }
#     let(:expected_total) { 3 }
#   end
RSpec.shared_examples "paginated index" do |path:|
  describe "GET #{path} pagination" do
    it "returns the envelope shape with default meta when no params are sent" do
      get path, headers: { "Authorization" => authorization_header }
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data).to be_a(Hash)
      expect(data.keys).to include("data", "meta")
      expect(data["data"]).to be_an(Array)
      expect(data["meta"]).to include(
        "current_page" => 1,
        "per_page" => 25,
        "total_count" => expected_total
      )
      expect(data["meta"]["total_pages"]).to eq(expected_total.zero? ? 0 : (expected_total / 25.0).ceil)
    end

    it "returns a bare array when ?paginated=false" do
      get "#{path}?paginated=false", headers: { "Authorization" => authorization_header }
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data).to be_an(Array)
      expect(data.size).to eq(expected_total)
    end

    it "respects per_page and page params" do
      skip "needs at least 2 records to verify navigation" if expected_total < 2

      get "#{path}?per_page=1&page=2", headers: { "Authorization" => authorization_header }
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["data"].size).to eq(1)
      expect(data["meta"]).to include(
        "current_page" => 2,
        "per_page" => 1,
        "total_count" => expected_total,
        "total_pages" => expected_total
      )
    end

    it "caps per_page at 100" do
      get "#{path}?per_page=999", headers: { "Authorization" => authorization_header }
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["meta"]["per_page"]).to eq(100)
    end
  end
end
