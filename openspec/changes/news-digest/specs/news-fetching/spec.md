## ADDED Requirements

### Requirement: News articles fetched from configured RSS feeds

The system SHALL fetch news articles from RSS/Atom feeds listed in `config/news_sources.yml` on a nightly schedule.

#### Scenario: Articles saved as documents

- **GIVEN** one or more RSS feeds are configured in `config/news_sources.yml`
- **WHEN** `FetchNewsJob` runs
- **THEN** each new article SHALL be saved as a `Document` with:
  - `source: 'news'`
  - `url` set to the article URL
  - `title` set to the article title
  - A `text` block containing the article description/summary

#### Scenario: Articles deduplicated by URL

- **GIVEN** an article with a given URL was already saved in a previous run
- **WHEN** `FetchNewsJob` processes the same feed again
- **THEN** no duplicate document SHALL be created for that URL

#### Scenario: Feed-level errors do not stop other feeds

- **GIVEN** one RSS feed URL is unreachable or returns invalid XML
- **WHEN** `FetchNewsJob` processes the list of feeds
- **THEN** the failing feed SHALL be skipped and logged
- **AND** all other feeds SHALL continue to be processed normally

#### Scenario: Item count per feed is limited

- **GIVEN** a feed contains 100+ items
- **WHEN** `FetchNewsJob` fetches that feed
- **THEN** at most `max_items_per_feed` (default: 20) items SHALL be processed per run

### Requirement: Articles tagged with feed name

- **WHEN** an article is saved
- **THEN** a `Tag` matching the feed's configured `tag` value SHALL be associated with the document
