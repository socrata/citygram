module Citygram::Models
  class Event < Sequel::Model
    many_to_one :publisher


    plugin :serialization, :geojson, :geom
    plugin :serialization, :pg_json, :properties
    plugin :geometry_validation

    dataset_module do
      def from_subscription(subscription, params = {})
        geom = GeoRuby::GeojsonParser.new.parse(subscription.geom).as_ewkt
        params[:publisher_id] = subscription.publisher_id
        from_geom(geom, params)
      end

      def from_geom(geom_ewkt, params)
        after_date = params[:after_date]
        before_date = params[:before_date]

        if after_date && before_date
          with_sql(<<-SQL, params.fetch(:publisher_id), after_date, before_date, geom_ewkt)
            SELECT events.*
            FROM events
            WHERE events.publisher_id = ?
              AND events.updated_at > ?
              AND events.updated_at <= ?
              AND ST_Intersects(events.geom, ?::geometry)
            ORDER BY events.updated_at DESC
          SQL
        else
          with_sql(<<-SQL, params.fetch(:publisher_id), geom_ewkt)
            SELECT events.*
            FROM events
            WHERE events.publisher_id = ?
              AND ST_Intersects(events.geom, ?::geometry)
            ORDER BY events.updated_at DESC
          SQL
        end
      end
    end

    def validate
      super
      validates_presence [:title, :geom, :feature_id]
      validates_geometry :geom
      # Validates the uniqueness of the event based on publisher id and feature id
      validates_unique [:publisher_id, :feature_id]
    end

    def need_update(new_event)
      return true unless new_event.title.squeeze(' ') == self.title.squeeze(' ')
      return true unless new_event.description == self.description
      return false
    end
  end
end
