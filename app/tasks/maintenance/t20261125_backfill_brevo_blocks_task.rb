# frozen_string_literal: true

module Maintenance
  # Records the addresses Brevo blocked before its webhook reached us.
  # Can run again: a block only moves its timestamps forward.
  class T20261125BackfillBrevoBlocksTask < MaintenanceTasks::Task
    # 3 600 requests an hour, out of the 3.6 M Brevo allows this endpoint: a quota it may share with sending
    PAGE_INTERVAL = 1.second

    # Day by day rather than one offset over the whole list: an address
    # unblocked meanwhile (a critical mail, the manager) moves every later row
    # one place back, and the next page skips one. Within a day, only for the
    # seconds spent on it.
    def enumerator_builder(cursor:)
      day, offset = cursor.present? ? parse_cursor(cursor) : [first_day, 0]

      Enumerator.new do |yielder|
        while day.present? && day < Date.current
          events = fetch_page(day:, offset:)
          day, offset = events.size < Brevo::API::BLOCKED_CONTACTS_MAX_LIMIT ? [day.next_day, 0] : [day, offset + events.size]

          # an empty page too: the run can stop, and keeps its place, between any two requests
          yielder.yield(events, "#{day.iso8601}/#{offset}")
          sleep(PAGE_INTERVAL)
        end
      end
    end

    def process(events)
      events.filter { it[:event] }.each { User.record_brevo_event(**it) }
    end

    private

    # Brevo's days may not be ours: starting one day early covers any time zone.
    def first_day
      fetch_page(offset: 0, limit: 1).first&.fetch(:at)&.to_date&.prev_day
    end

    def parse_cursor(cursor)
      day, offset = cursor.split('/')
      [Date.iso8601(day), offset.to_i]
    end

    def fetch_page(**params)
      Brevo::API.new.blocked_contacts(**params).value_or do |error|
        raise "Brevo blocked contacts #{params.to_json}: #{error.kind} HTTP #{error.http_code} #{error.brevo_code} #{error.message}"
      end
    end
  end
end
