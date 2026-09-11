// Geographic primitives shared by every page and util.
//
// `latitude` / `longitude` is the only spelling used inside the app. Leaflet's
// `lat` / `lng` never leaves `utils/geo.ts`, where it is converted at the edge.

/** A WGS-84 position in decimal degrees. */
export interface Coordinate {
  latitude: number;
  longitude: number;
}

/** Degree deltas, used to translate a precomputed layout to the cursor. */
export interface CoordinateOffset {
  latitudeDelta: number;
  longitudeDelta: number;
}

/** An ordered list of waypoints a vehicle drives through. */
export interface MovementPath {
  waypoints: Coordinate[];
}
