## 1. Database Migration

- [ ] 1.1 Generate: `rails generate migration AddUrlToDocuments url:string:index`
- [ ] 1.2 Run migration on development; run on RPi after deploy

## 2. Gemfile

- [ ] 2.1 Add `gem 'feedjira'` to `Gemfile` and run `bundle install`

## 3. News Sources Config

- [ ] 3.1 Create `config/news_sources.yml`:
  ```yaml
  sources:
    - name: "Хабр"
      url: "https://habr.com/ru/rss/best/daily/"
      tag: "tech"
      max_items: 20
    # Add more sources here
  ```
- [ ] 3.2 Add sources the user wants to track

## 4. FetchNewsJob

- [ ] 4.1 Create `app/jobs/fetch_news_job.rb`:

  ```ruby
  class FetchNewsJob < ApplicationJob
    queue_as :default

    def perform
      config = YAML.load_file(Rails.root.join('config/news_sources.yml'))
      config['sources'].each do |source|
        fetch_feed(source)
      rescue StandardError => e
        Rails.logger.error("FetchNewsJob: feed '#{source['name']}' failed: #{e.message}")
      end
    end

    private

    def fetch_feed(source)
      feed = Feedjira.parse(HTTP.timeout(30).get(source['url']).body.to_s)
      max_items = source.fetch('max_items', 20)
      tag = Tag.find_or_create_by!(name: source['tag'])

      feed.entries.first(max_items).each do |entry|
        next if Document.exists?(url: entry.url)

        doc = Document.create!(
          title: entry.title.truncate(100),
          source: 'news',
          url: entry.url
        )
        doc.document_tags.create!(tag: tag)
        doc.blocks.create!(
          block_type: 'text',
          position: 0,
          content: { text: entry.summary.to_s.gsub(/<[^>]+>/, '').strip.truncate(1000) }.to_json
        )
      end
    end
  end
  ```

## 5. SendNewsDigestJob

- [ ] 5.1 Create `app/jobs/send_news_digest_job.rb`:

  ```ruby
  class SendNewsDigestJob < ApplicationJob
    queue_as :default

    def perform
      today_docs = Document.where(source: 'news')
                           .where(created_at: Time.current.beginning_of_day..)
                           .includes(:tags, :blocks)

      return if today_docs.none?

      summary = build_summary(today_docs)
      bot = Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
      bot.api.send_message(
        chat_id: ENV['TELEGRAM_ALLOWED_USER_ID'],
        text: "📰 Сводка новостей за #{Date.today.strftime('%d.%m.%Y')}\n\n#{summary}",
        parse_mode: 'HTML'
      )
    end

    private

    def build_summary(docs)
      titles_by_tag = docs.group_by { |d| d.tags.first&.name || 'other' }
                          .transform_values { |ds| ds.map(&:title) }

      ollama_summary(titles_by_tag) || fallback_list(titles_by_tag)
    end

    def ollama_summary(titles_by_tag)
      items_text = titles_by_tag.map { |tag, titles|
        "#{tag}:\n#{titles.map { |t| "- #{t}" }.join("\n")}"
      }.join("\n\n")

      response = HTTP.timeout(120).post(
        "#{ENV.fetch('OLLAMA_BASE_URL', 'http://ollama:11434')}/api/generate",
        json: {
          model: ENV.fetch('OLLAMA_CORRECTION_MODEL', 'gemma3:4b'),
          prompt: "Summarize these news items in 3-5 sentences in Russian. Be concise and factual.\n\n#{items_text}",
          stream: false
        }
      )
      return nil unless response.status.success?
      JSON.parse(response.body)['response']&.strip.presence
    rescue StandardError => e
      Rails.logger.warn("Digest Ollama summary failed: #{e.message}")
      nil
    end

    def fallback_list(titles_by_tag)
      titles_by_tag.map { |tag, titles|
        "<b>#{tag}</b>\n#{titles.map { |t| "• #{t}" }.join("\n")}"
      }.join("\n\n")
    end
  end
  ```

## 6. Recurring Schedule

- [ ] 6.1 Add to `config/recurring.yml` under `production:`:
  ```yaml
  fetch_news:
    class: FetchNewsJob
    schedule: at 2am every day
  send_news_digest:
    class: SendNewsDigestJob
    schedule: at 8pm every day
  ```

## 7. Verification

- [ ] 7.1 Manually enqueue `FetchNewsJob`: `rails runner 'FetchNewsJob.perform_now'` → check documents created with `source: 'news'`
- [ ] 7.2 Manually enqueue `SendNewsDigestJob` → check Telegram for digest message
- [ ] 7.3 Run fetch twice → verify no duplicate documents (same URL)
- [ ] 7.4 Check `Document.where(source: 'news').count` before and after
