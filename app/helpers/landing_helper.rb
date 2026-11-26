module LandingHelper
  ICON_PATHS = {
    voice: "M4 10v4m4-8v12m4-15v18m4-15v12m4-8v4",
    flow: "M5 4v12a3 3 0 0 0 3 3h11M5 9h8a4 4 0 0 1 4 4v6M2 4h6m8 12 3 3-3 3",
    decision: "m12 3 9 9-9 9-9-9Z",
    tool: "m8 5-6 7 6 7m8-14 6 7-6 7m-3-16-2 18",
    check: "m5 12 4 4L19 6",
    person: "M16 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0ZM4 21v-2a8 8 0 0 1 16 0v2",
    phone: "M7 3H3v4c0 8 6 14 14 14h4v-4l-5-2-2 2a13 13 0 0 1-7-7l2-2Z",
    message: "M4 4h16v12H9l-5 4Z",
    arrow: "M4 12h16m-6-6 6 6-6 6",
    shield: "m12 2 8 3v6c0 5-4 9-8 11-4-2-8-6-8-11V5Zm-4 9 3 3 5-6"
  }.freeze

  def landing_icon(name)
    path = tag.path(d: ICON_PATHS.fetch(name.to_sym), fill: "none", stroke: "currentColor", "stroke-width": 1.5, "stroke-linecap": "round", "stroke-linejoin": "round")
    tag.svg(path, viewBox: "0 0 24 24", "aria-hidden": true, class: "lp-icon")
  end
end
