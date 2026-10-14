import 'package:flutter/widgets.dart';

import 'models/report.dart';

// All text for the feature, in English (en) and Marathi (mr). Hindi and Konkani fall back to
// English until they are written. The Marathi below is a MACHINE-WRITTEN DRAFT: a native
// speaker must review it before any villager sees it (docs/FRONTEND_PLAN.md §7).
//
// Copy rules: plain verbs, one word per idea, suggestion wording only ("may help", "could
// suit"; never "you qualify", "approved", "best"), and an honest line wherever data is missing.
//
// The server sends reasons as {key, params}. `reason()` turns one into a sentence, so a cached
// report still renders offline and the language can change without asking the server again.

const Map<String, Map<String, String>> _text = {
  'en': {
    // screens and actions
    'lv_title': 'My livelihood report',
    'lv_card_title': 'My livelihood',
    'lv_card_sub': 'See resources near your land and work you could start',
    'lv_tab': 'Livelihood',
    'lv_demo_banner':
        'Demo with a sample farmer. The report does not change with the details you enter.',
    'lv_ask_ai': 'Ask AI',
    'lv_hub_section': 'What would you like to do?',
    'lv_hub_add_sub': 'A few questions about your land and animals',
    'lv_hub_ask_sub': 'Ask a question about your own report',
    'lv_hub_report_sub': 'Resources near your land and ideas that may suit you',
    'lv_hub_resources': 'Resources near me',
    'lv_hub_resources_sub': 'Water, markets and more around your land',
    'lv_hub_schemes': 'Government schemes',
    'lv_hub_schemes_sub': 'Official pages to check yourself. We never promise money',
    'lv_hub_edit_sub': 'Land, animals and what you own',
    'lv_hub_policy_sub': 'Why we never suggest anything that harms wildlife',
    'lv_home_intro':
        'See what is around your land and work you could start. Everything here is a suggestion for you to check.',
    'lv_show_report': 'Show my report',
    'lv_open_resources': 'See all resources',
    'lv_back': 'Back',
    'lv_loading': 'Preparing your report',
    'lv_load_failed':
        'We could not open your report. Check your connection and try again.',
    'lv_retry': 'Try again',
    // intake form
    'lv_add_details': 'Add your details',
    'lv_edit_details': 'Change my details',
    'lv_details_saved': 'Your details are saved on this phone.',
    'lv_no_details_yet':
        'You have not added details yet. Add them to get ideas that fit you.',
    'lv_delete_answers': 'Delete my answers',
    'lv_delete_title': 'Delete your answers?',
    'lv_delete_body':
        'This removes the details you entered. Your report goes back to a general list. This cannot be undone.',
    'lv_delete_confirm': 'Delete answers',
    'lv_keep': 'Keep them',
    'lv_deleted': 'Your answers were deleted.',
    'lv_step_of': 'Step {n} of {total}',
    'lv_step_land': 'Your land',
    'lv_step_animals': 'Your animals',
    'lv_step_own': 'What you already have',
    'lv_step_work': 'Past work and money',
    'lv_step_location': 'Where is your land?',
    'lv_optional_note':
        'Every question is optional. Only you can see your answers. You can delete them any time.',
    'lv_next': 'Next',
    'lv_save_details': 'Save my details',
    'lv_land_area': 'How much land do you have?',
    'lv_area_hint': 'Land area',
    'lv_unit_hectare': 'Hectare',
    'lv_unit_acre': 'Acre',
    'lv_unit_guntha': 'Guntha',
    'lv_area_converted': 'About {ha} hectares',
    'lv_err_area': 'Enter a number greater than zero.',
    'lv_area_check': 'That is a lot of land. Please check the number.',
    'lv_land_type': 'Type of land',
    'lv_type_irrigated': 'Irrigated',
    'lv_type_rain_fed': 'Rain-fed',
    'lv_type_mixed': 'Both',
    'lv_water_on_land': 'Water on your land',
    'lv_water_open_well': 'Open well',
    'lv_water_borewell': 'Borewell',
    'lv_water_none': 'None',
    'lv_animals_hint': 'Tap + for each animal you own.',
    'lv_own_hint': 'Tick what you already have.',
    'lv_work_title': 'What did you grow or do in the last 3 years?',
    'lv_family_workers': 'Family members who can work',
    'lv_money': 'Money you can invest',
    'lv_money_low': 'Low',
    'lv_money_medium': 'Medium',
    'lv_money_high': 'High',
    'lv_loc_gps': 'Use my current location',
    'lv_loc_manual': 'Type the coordinates',
    'lv_loc_village': 'Use my village centre',
    'lv_loc_village_note':
        'The report will be measured from your village centre, not from your plot.',
    'lv_lat': 'Latitude',
    'lv_lng': 'Longitude',
    'lv_loc_default': 'Use default coordinates',
    'lv_loc_default_note':
        'Fills in 19.7805, 73.2210: the sample village near Trimbak that the demo data is built around.',
    'lv_loc_getting': 'Finding your location',
    'lv_loc_got': 'Location found: {lat}, {lng}',
    'lv_loc_accuracy': 'Accurate to about {acc} m',
    'lv_loc_denied':
        'Location permission was denied. Type the coordinates or use your village centre.',
    'lv_loc_denied_forever':
        'Location is blocked for this app. Allow it in the phone settings, or type the coordinates.',
    'lv_loc_off':
        'Location is switched off on this phone. Switch it on, or type the coordinates.',
    'lv_loc_failed':
        'We could not find your location. Try again, or type the coordinates.',
    'lv_err_outside_mh':
        'This place is outside Maharashtra. Check the numbers.',
    'lv_err_coords': 'Enter both the latitude and the longitude.',
    'lv_save_failed': 'We could not save your details. Try again.',
    'lv_showing_saved':
        'Showing your last saved report. We could not refresh it just now.',
    'lv_sync_pending':
        'Saved on this phone. It will be sent when you are online.',
    'lv_err_offline': 'No internet right now. Try again when you are online.',
    'lv_err_signin': 'Please sign in again to see your report.',
    'lv_err_role': 'This part is for villagers and Gram Sabha members.',
    'lv_err_no_village':
        'Your account is not linked to a village yet. Ask the Gram Sabha office.',
    'lv_err_data':
        'The resource data is not ready yet. Please try again later.',
    'lv_err_radius': 'That distance is not allowed. Use up to 10 km.',
    'lv_err_server':
        'The server had a problem. Please try again in a little while.',
    'lv_err_generic': 'Something went wrong. Please try again.',
    'w_paddy': 'Paddy',
    'w_millets': 'Millets',
    'w_pulses': 'Pulses',
    'w_vegetables': 'Vegetables',
    'w_fruit': 'Fruit',
    'w_dairy': 'Dairy',
    'w_goat_rearing': 'Goat rearing',
    'w_poultry': 'Poultry',
    'w_forest_produce': 'Forest produce',
    'w_labour': 'Labour',
    'w_other': 'Other',
    // sections
    'lv_sec_resources': 'Resources within {radius_km} km',
    'lv_sec_own': 'What you already have',
    'lv_sec_heading': 'Where you are heading',
    'lv_sec_ideas': 'Ideas for you',
    'lv_sec_build_on': 'Build on your work',
    'lv_sec_other': 'Other options',
    'lv_sec_why_not': 'Why not others?',
    'lv_sec_weather': 'Weather in your area',
    'lv_sec_strengths': 'Helps you',
    'lv_sec_constraints': 'Watch out for',
    'lv_sec_next': 'Next steps',
    // header
    'lv_from_plot': 'Measured from your plot',
    'lv_from_village': 'Measured from your village centre',
    'lv_report_for': 'For {name}',
    // labels and badges
    'lv_useful': 'Useful',
    'lv_partly_useful': 'Partly useful',
    'lv_not_useful': 'Not useful',
    'lv_all': 'All',
    'lv_fit_good': 'Good fit',
    'lv_fit_fair': 'Fair fit',
    'lv_fit_weak': 'Weak fit',
    'lv_wildlife_low': 'Wildlife risk: low',
    'lv_wildlife_medium': 'Wildlife risk: medium',
    'lv_wildlife_needs_permission': 'Needs Forest Department permission',
    'lv_cost_low': 'Low cost',
    'lv_cost_medium': 'Medium cost',
    'lv_cost_high': 'High cost',
    'lv_season_year_round': 'All year',
    'lv_season_kharif': 'Kharif',
    'lv_season_rabi': 'Rabi',
    'lv_season_summer': 'Summer',
    'lv_season_post_monsoon': 'After monsoon',
    'lv_tag_inside_cfr': 'Community forest',
    'lv_tag_inside_village': 'In your village',
    'lv_tag_near': 'Nearby',
    'lv_gram_sabha_only': 'Use only through the Gram Sabha',
    // trust and honesty
    'lv_told_by_you': 'Told by you, not verified',
    'lv_to_verify': 'To be verified on the ground',
    'lv_confirmed': 'Confirmed by the committee',
    'lv_not_checked': 'Not yet checked on the ground',
    'lv_source': 'Source',
    'lv_date_unknown': 'date not known',
    'lv_sample': 'Sample',
    'lv_sample_note': 'Sample data for a demo. These are not real places.',
    'lv_draft_idea': 'Draft idea, not expert-reviewed',
    'lv_footer':
        'Suggestion only. Check on the ground. The Gram Sabha decides.',
    'lv_policy_link': 'Read our policy',
    'lv_policy_title': 'Wildlife policy',
    'lv_policy_body':
        'VanMitra does not support hunting, trapping, selling of wildlife or wildlife parts, or any activity that harms animals or their homes.',
    'lv_policy_check':
        'Ideas near protected areas must be cleared with the Forest Department first. We say "check with the Forest Department", not "safe", because our map layers are not complete.',
    'lv_no_resources':
        'No resources found within {radius_km} km in our data. This does not mean there are none.',
    'lv_no_ideas':
        'No ideas to show yet. Add your details to get ideas that fit you.',
    'lv_weather_note': 'Typical, from past years. Not a forecast.',
    'lv_weather_rain': 'Rain (mm)',
    'lv_disasters_none':
        'No record of past disasters found in our data. This does not mean there were none.',
    'lv_held_back': 'Held back: other ideas fit you better',
    'lv_gate_removed': 'Removed: {why}',
    // told-by-you names
    'a_cow': 'Cow',
    'a_buffalo': 'Buffalo',
    'a_bullock': 'Bullock',
    'a_goat_sheep': 'Goat or sheep',
    'a_poultry': 'Poultry', 'a_other': 'Other animals',
    's_well': 'Well',
    's_borewell': 'Borewell',
    's_farm_pond': 'Farm pond',
    's_shed': 'Shed',
    's_pump': 'Pump',
    's_drip_kit': 'Drip kit',
    's_bullock_cart': 'Bullock cart',
    's_storage_room': 'Storage room',
    's_vehicle': 'Vehicle',
    's_fodder_land': 'Fodder land',
    's_other': 'Other',
    // resource kinds
    'k_water_body': 'Pond or tank',
    'k_well': 'Well',
    'k_water_structure': 'Check dam or farm pond',
    'k_river': 'River',
    'k_drainage_line': 'Stream',
    'k_forest_compartment': 'Forest',
    'k_conservation_reserve': 'Conservation reserve',
    'k_wildlife_compartment': 'Wildlife area',
    'k_grazing_land': 'Grazing land',
    // resource reasons
    'reason.water_dry': 'Dry for most of the year',
    'reason.silted': 'Silt has built up',
    'reason.poor_condition': 'In poor condition',
    'reason.low_water_months': 'Has water for only {months} months',
    'reason.far_from_you': 'Far from you: {distance_m_fmt}',
    'reason.not_checked': 'Nothing about it has been checked yet',
    'reason.good_all_round': 'Has water and is in good condition',
    'reason.good_on_what_is_known': 'Looks good on what we know',
    'reason.not_fully_checked': 'Only partly checked',
    'reason.held_back_lower_fit': 'Other ideas fit you better',
    // gates
    'gate.land_sale_or_lease':
        'Land cannot be sold or leased (FRA Section 4(4))',
    'gate.hunting_or_trapping':
        'Hunting and trapping are not allowed (FRA Section 3(1)(l))',
    'gate.timber_or_harm':
        'Cutting timber or harming wildlife is not allowed (FRA Section 5)',
    'gate.not_allowed_in_cfr': 'Not allowed in community forest',
    // idea reasons
    'idea.reason.missing_need': 'Needs {need} nearby, and we found none',
    'idea.reason.animals_and_resources':
        'You keep animals, and the water and fodder they need are within reach',
    'idea.reason.matches_past_work': 'Matches work you have done before',
    'idea.reason.community_resource': 'Uses a community resource near you',
    'idea.reason.good_resources_nearby': 'The resources it needs are nearby',
    'idea.reason.fits_basic': 'Could suit you; add your details to check',
    // idea flags
    'flag.through_gram_sabha': 'Use only through the Gram Sabha',
    'flag.group_only': 'Works only as a group through the Gram Sabha',
    'flag.ask_forest_dept': 'Ask the Forest Department first',
    'flag.possible_flood_risk': 'Possible flood risk near you',
    'flag.hot_area_water_need': 'Hot area: needs a lot of water',
    'flag.missing_need': 'Missing: {need}',
    'flag.land_unknown': 'Needs about {min_ha} ha; tell us your land',
    'flag.needs_more_land': 'Needs about {min_ha} ha; you entered {have_ha} ha',
    // analysis
    'analysis.headline.livestock':
        'Your animals and nearby water point towards livestock work',
    'analysis.headline.well':
        'Water you can reach points towards vegetable and nursery work',
    'analysis.headline.mushroom': 'A small shed could start mushroom farming',
    'analysis.headline.farm_land': 'Your land points towards farming ideas',
    'analysis.headline.forest_produce':
        'Forest nearby points towards forest produce',
    'analysis.headline.grazing':
        'Grazing land nearby points towards fodder work',
    'analysis.headline.pond_dam_tank':
        'A pond nearby points towards fish culture as a group',
    'analysis.headline.community_forest':
        'Community forest nearby points towards forest work through the Gram Sabha',
    'analysis.headline.generic':
        'Add your details to see where you are heading',
    'analysis.water_nearby':
        '{count} water sources within {radius_km} km; the nearest is {nearest_m_fmt} away',
    'analysis.own_water_source': 'You have a water source of your own',
    'analysis.no_water_nearby':
        'No water source found within {radius_km} km in our data',
    'analysis.grazing_nearby': 'Grazing land is {nearest_m_fmt} away',
    'analysis.forest_nearby': 'Forest nearby ({count})',
    'analysis.forest_nearby_gs':
        'Forest nearby ({count}); use it only through the Gram Sabha',
    'analysis.water_is_seasonal': 'Nearby water lasts only part of the year',
    'analysis.possible_flood_risk': 'Your plot may be at risk of flooding',
    'analysis.near_protected_area': 'A protected area is {nearest_m_fmt} away',
    'analysis.ask_forest_dept': 'Ask the Forest Department before starting',
    'analysis.you_have_animals': 'You keep: {list}',
    'analysis.you_have_assets': 'You have: {list}',
    'analysis.your_land': 'Your land: about {area_ha} ha',
    'analysis.no_fodder_nearby':
        'No grazing land found within {radius_km} km for your animals',
    'analysis.verify_with_frc':
        'Ask the Forest Rights Committee to check these on the ground',
    'analysis.add_details': 'Add your details to improve this report',
    // notes
    'note.profile_incomplete':
        'You have not added details yet, so this list is general.',
    'note.land_area_missing': 'Add your land area to check which ideas fit.',
    'note.from_village_centre':
        'Measured from your village centre. Pin your plot for a closer report.',
    'note.market_not_checked': 'Market access is not checked yet.',
    'note.dataset_is_sample': 'This report uses sample data, not real surveys.',
    'note.no_resources_found': 'No resources were found near this point.',
    'note.fewer_than_five': 'Fewer than five ideas passed the checks.',
    // Ask about your report
    'ask.title': 'Ask about your report',
    'ask.entry': 'Ask about your report',
    'ask.entry_sub': 'Ask a question. Answers come only from your own report.',
    'ask.intro':
        'Ask a question about your own report. I can only answer from what is in it.',
    'ask.hint': 'Type your question',
    'ask.send': 'Send',
    'ask.thinking': 'Looking in your report',
    'ask.suggestions': 'You could ask',
    'ask.clear': 'Clear my questions',
    'ask.clear_title': 'Clear your questions?',
    'ask.clear_body':
        'This deletes the questions you asked and the answers. Your report stays. This cannot be undone.',
    'ask.clear_confirm': 'Clear',
    'ask.cleared': 'Your questions were cleared.',
    'ask.from': 'From: {parts}',
    'ask.part.summary': 'your summary',
    'ask.part.ideas': 'your ideas',
    'ask.part.resources': 'resources near you',
    'ask.part.removed': 'ideas that were left out',
    'ask.part.weather': 'weather',
    'ask.part.your_details': 'what you told us',
    'ask.sample_note': 'Based on sample data, not real surveys.',
    'ask.question_not_kept': 'Question not kept',
    'ask.refused_harmful':
        'This is not allowed under our policy. VanMitra does not support any harm to wildlife.',
    'ask.off_topic': 'I can only answer questions about your report.',
    'ask.not_in_report':
        'This is not in your report. Please ask the agriculture officer or the Forest Department.',
    'ask.nir.outside':
        'Prices, loans, insurance, crop problems and animal attacks are not part of your report.',
    'ask.nir.schemes':
        'Government schemes are not in your report yet. Ask the agriculture officer.',
    'ask.nir.idea_unchecked':
        'We have not checked this idea for your land. Ask an expert before you spend money on it.',
    'ask.nir.idea_not_shown':
        'This idea is not shown for you, so it is not in your report.',
    'ask.nir.no_ideas':
        'Your report has no ideas yet. Add your details to get ideas.',
    'ask.top_ideas': 'Your top {count} ideas',
    'ask.item.idea': '{rank}. {name}: {fit_text}',
    'ask.idea.in_report': '{name} is number {rank} in your report: {fit_text}',
    'ask.idea.removed_by_gate': '{name} was removed. {gate_text}',
    'ask.idea.held_back':
        '{name} was held back because other ideas fit you better.',
    'ask.item.cost': '{cost_text}',
    'ask.item.season': 'Best season: {season_text}',
    'ask.item.wildlife': '{wildlife_text}',
    'ask.item.idea_wildlife': '{name}: {wildlife_text}',
    'ask.item.idea_cost': '{name}: {cost_text}',
    'ask.item.idea_gram_sabha': '{name}: use only through the Gram Sabha',
    'ask.item.removed': '{name}: {gate_text}',
    'ask.item.held_back': '{name}: other ideas fit you better',
    'ask.water.header': 'Water within {radius_km} km',
    'ask.item.resource':
        '{name}: {kind_text}, {distance_m_fmt} away, {label_text}',
    'ask.resources.header':
        '{total} resources within {radius_km} km: {useful} useful, {partly_useful} partly useful, {not_useful} not useful',
    'ask.wildlife.near':
        'A protected area is near your plot. Ask the Forest Department first.',
    'ask.wildlife.none_found':
        'No protected area was found near your plot in our data. This does not mean there is none. If unsure, ask the Forest Department.',
    'ask.flood.possible': 'Your plot may be at risk of flooding.',
    'ask.flood.none_found':
        'No flood risk was found in our data. This does not mean there is none.',
    'ask.weather.header':
        'Typical weather in your area, from past years. Not a forecast.',
    'ask.weather.hottest': 'Hottest month: {month_name}, about {tmax_c} °C',
    'ask.weather.wettest':
        'Wettest month: {month_name}, about {rain_mm} mm of rain',
    'ask.weather.driest':
        'Driest month: {month_name}, about {rain_mm} mm of rain',
    'ask.cost.header': 'What your top ideas cost to start',
    'ask.forest.header': 'Forest near you',
    'ask.forest.none_found':
        'No forest was found near you in our data. This does not mean there is none.',
    'ask.own.header': 'What you told us',
    'ask.own.none':
        'You have not told us about your land, animals or what you own yet. Add your details to see them here.',
    'ask.removed.header': '{count} ideas are not in your top list',
    'ask.removed.none': 'No ideas were left out of your report.',
    'ask.schemes.header':
        'Schemes that may relate to your ideas. We only link to official pages and cannot say whether you qualify.',
    'ask.item.idea_schemes': '{name}: {count} schemes may relate',
    'ask.chip.schemes': 'Which schemes may help?',
    'ask.ai_consent_title': 'Let an AI assistant answer other questions?',
    'ask.ai_consent_body':
        'For questions our own answers cannot cover, an AI assistant can read the facts of your report. We never send your name or the exact place of your plot. The question you type is sent too, so do not type your name or phone number. Its answers are checked against your report, but please check them yourself.',
    'ask.ai_allow': 'Allow',
    'ask.ai_deny': 'Not now',
    'ask.ai_toggle': 'AI assistant may read my report facts',
    'ask.ai_label':
        'Written by an AI assistant from your report. Please check it yourself.',
    'ask.ai_answer': 'Answer from the AI assistant',
    'ask.chip.heading': 'Where am I heading?',
    'ask.chip.top_ideas': 'What are my best ideas?',
    'ask.chip.idea': 'Tell me about {name}',
    'ask.chip.water': 'Is there water near me?',
    'ask.chip.wildlife': 'Is a protected area near me?',
    'ask.chip.cost': 'What will my ideas cost?',
    'ask.chip.forest': 'What about the forest near me?',
    'ask.chip.own': 'What did I tell you?',
    'ask.chip.weather': 'How is the weather?',
    'ask.chip.removed': 'Why were other ideas left out?',
    'm_1': 'January',
    'm_2': 'February',
    'm_3': 'March',
    'm_4': 'April',
    'm_5': 'May',
    'm_6': 'June',
    'm_7': 'July',
    'm_8': 'August',
    'm_9': 'September',
    'm_10': 'October',
    'm_11': 'November',
    'm_12': 'December',
    // Idea detail and schemes (stage 3)
    'idea.title': 'Idea details',
    'idea.rank': 'Number {rank} in your report',
    'idea.status_removed': 'Not suggested: a law check stops it',
    'idea.status_held_back': 'Held back: other ideas fit you better',
    'idea.why': 'Why this idea',
    'idea.needs': 'What it needs',
    'idea.need_met_own': 'You have: {what}',
    'idea.need_met_near': 'Found near you: {what}',
    'idea.need_missing': 'Not found: {what}',
    'idea.or': ' or ',
    'idea.checks': 'Checks that ran',
    'idea.check.passed': 'Passed',
    'idea.check.flagged': 'Look at this',
    'idea.check.not_checked': 'Not checked yet',
    'idea.check_name.law': 'Law',
    'idea.check_name.wildlife': 'Wildlife',
    'idea.check_name.needs': 'What it needs',
    'idea.check_name.land': 'Land',
    'idea.check_name.community': 'Community forest',
    'detail.check.law':
        'It passed the four legal checks. This is not legal advice; the Gram Sabha decides.',
    'detail.check.wildlife_low':
        'Low wildlife risk. If you are unsure, ask the Forest Department.',
    'detail.check.wildlife_medium':
        'Medium wildlife risk. Ask the Forest Department before you start.',
    'detail.check.wildlife_needs_permission':
        'Needs Forest Department permission before you start.',
    'detail.check.needs_met': 'What it needs is near you, or already yours.',
    'detail.check.needs_missing': 'Something it needs was not found near you.',
    'detail.check.land_ok': 'Your land is enough for this idea.',
    'detail.weather.flood_risk':
        'Your plot may flood. Plan for the rainy months.',
    'detail.weather.heat':
        'This idea needs care in the heat. The hottest month in your area is {month_name}, about {tmax_c} °C.',
    'detail.weather.typical':
        'Typical weather for your area is in your report. It is not a forecast.',
    'idea.resources': 'Resources it would use',
    'idea.warnings': 'Things to watch',
    'idea.weather': 'Weather note',
    'idea.schemes': 'Schemes that may relate',
    'idea.schemes_note':
        'We only link to official pages. We cannot say whether you qualify.',
    'idea.schemes_none': 'No schemes are listed for this idea yet.',
    'idea.see_all_schemes': 'See all schemes',
    'idea.schemes_count': '{count} schemes may relate',
    'idea.open': 'See details',
    'sch.title': 'Schemes',
    'sch.entry': 'Government and NGO schemes',
    'sch.entry_sub': 'Links to official pages. We never take applications.',
    'sch.tab_government': 'Government',
    'sch.tab_ngo': 'NGO',
    'sch.filter_help': 'Type of help',
    'sch.filter_who': 'For',
    'sch.filter_all': 'All',
    'sch.help.farming': 'Farming',
    'sch.help.fishing': 'Fishing',
    'sch.help.livestock': 'Livestock',
    'sch.help.small_business': 'Small business',
    'sch.help.forest_produce': 'Forest produce',
    'sch.aud.women': 'Women',
    'sch.aud.tribal': 'Tribal communities',
    'sch.aud.farmers': 'Farmers',
    'sch.aud.groups': 'Groups',
    'sch.runs': 'Run by: {who}',
    'sch.who': 'Who can apply',
    'sch.documents': 'Papers usually asked for',
    'sch.last_checked': 'Last checked: {date}',
    'sch.never_checked': 'Not checked by a person yet',
    'sch.open': 'Open official page',
    'sch.no_page': 'Official page not added yet',
    'sch.open_failed': 'Could not open the page. Try again later.',
    'sch.empty_register': 'No schemes have been added yet.',
    'sch.empty_filter': 'No scheme matches these filters.',
    'sch.disclaimer':
        'We only link to official pages. We do not take applications and cannot say whether you qualify. Read the rules and amounts on the official page.',
    'sch.sample_note': 'Sample rows for a demo. These are not real schemes.',
  },
  'mr': {
    'lv_title': 'माझा रोजगार अहवाल',
    'lv_card_title': 'माझा रोजगार',
    'lv_card_sub': 'तुमच्या जमिनीजवळची साधने आणि सुरू करता येतील अशी कामे पहा',
    'lv_tab': 'रोजगार',
    'lv_demo_banner':
        'नमुना शेतकऱ्यासह डेमो. तुम्ही भरलेल्या माहितीनुसार अहवाल बदलत नाही.',
    'lv_ask_ai': 'AI ला विचारा',
    'lv_hub_section': 'तुम्हाला काय करायचे आहे?',
    'lv_hub_add_sub': 'तुमची जमीन आणि जनावरांबद्दल काही प्रश्न',
    'lv_hub_ask_sub': 'तुमच्या स्वतःच्या अहवालाबद्दल प्रश्न विचारा',
    'lv_hub_report_sub': 'जमिनीजवळची साधने आणि तुम्हाला उपयोगी पडू शकतील अशा कल्पना',
    'lv_hub_resources': 'माझ्या जवळची साधने',
    'lv_hub_resources_sub': 'तुमच्या जमिनीभोवतीचे पाणी, बाजार आणि बरेच काही',
    'lv_hub_schemes': 'सरकारी योजना',
    'lv_hub_schemes_sub': 'तुम्ही स्वतः तपासण्यासाठी अधिकृत पाने. आम्ही पैशांचे आश्वासन देत नाही',
    'lv_hub_edit_sub': 'जमीन, जनावरे आणि तुमच्याकडे असलेली साधने',
    'lv_hub_policy_sub': 'वन्यजीवांना हानी पोहोचवणारे काहीही आम्ही का सुचवत नाही',
    'lv_home_intro':
        'तुमच्या जमिनीभोवती काय आहे आणि कोणते काम सुरू करता येईल ते पहा. येथील सर्व काही तुम्ही तपासून पाहण्यासाठीची सूचना आहे.',
    'lv_show_report': 'माझा अहवाल दाखवा',
    'lv_open_resources': 'सर्व साधने पहा',
    'lv_back': 'मागे',
    'lv_loading': 'तुमचा अहवाल तयार होत आहे',
    'lv_load_failed':
        'तुमचा अहवाल उघडता आला नाही. इंटरनेट तपासा आणि पुन्हा प्रयत्न करा.',
    'lv_retry': 'पुन्हा प्रयत्न करा',
    'lv_add_details': 'तुमची माहिती भरा',
    'lv_edit_details': 'माझी माहिती बदला',
    'lv_details_saved': 'तुमची माहिती या फोनवर जतन केली आहे.',
    'lv_no_details_yet':
        'तुम्ही अजून माहिती भरलेली नाही. तुम्हाला जुळणाऱ्या कल्पनांसाठी ती भरा.',
    'lv_delete_answers': 'माझी उत्तरे हटवा',
    'lv_delete_title': 'तुमची उत्तरे हटवायची?',
    'lv_delete_body':
        'तुम्ही भरलेली माहिती काढून टाकली जाईल. तुमचा अहवाल सर्वसाधारण यादीवर परत जाईल. हे परत करता येणार नाही.',
    'lv_delete_confirm': 'उत्तरे हटवा',
    'lv_keep': 'ठेवा',
    'lv_deleted': 'तुमची उत्तरे हटवली आहेत.',
    'lv_step_of': 'पायरी {n} पैकी {total}',
    'lv_step_land': 'तुमची जमीन',
    'lv_step_animals': 'तुमची जनावरे',
    'lv_step_own': 'तुमच्याकडे आधीच काय आहे',
    'lv_step_work': 'पूर्वीचे काम आणि पैसे',
    'lv_step_location': 'तुमची जमीन कुठे आहे?',
    'lv_optional_note':
        'प्रत्येक प्रश्न ऐच्छिक आहे. तुमची उत्तरे फक्त तुम्हीच पाहू शकता. ती तुम्ही केव्हाही हटवू शकता.',
    'lv_next': 'पुढे',
    'lv_save_details': 'माझी माहिती जतन करा',
    'lv_land_area': 'तुमच्याकडे किती जमीन आहे?',
    'lv_area_hint': 'जमिनीचे क्षेत्र',
    'lv_unit_hectare': 'हेक्टर',
    'lv_unit_acre': 'एकर',
    'lv_unit_guntha': 'गुंठा',
    'lv_area_converted': 'सुमारे {ha} हेक्टर',
    'lv_err_area': 'शून्यापेक्षा मोठी संख्या भरा.',
    'lv_area_check': 'ही खूप मोठी जमीन आहे. कृपया संख्या तपासा.',
    'lv_land_type': 'जमिनीचा प्रकार',
    'lv_type_irrigated': 'बागायती',
    'lv_type_rain_fed': 'जिरायती',
    'lv_type_mixed': 'दोन्ही',
    'lv_water_on_land': 'तुमच्या जमिनीवरील पाणी',
    'lv_water_open_well': 'उघडी विहीर',
    'lv_water_borewell': 'बोअरवेल',
    'lv_water_none': 'नाही',
    'lv_animals_hint': 'तुमच्याकडील प्रत्येक जनावरासाठी + दाबा.',
    'lv_own_hint': 'तुमच्याकडे आधीच जे आहे त्यावर खूण करा.',
    'lv_work_title': 'गेल्या ३ वर्षांत तुम्ही काय पिकवले किंवा कोणते काम केले?',
    'lv_family_workers': 'कामाला येऊ शकणारे कुटुंबातील सदस्य',
    'lv_money': 'तुम्ही गुंतवू शकता असे पैसे',
    'lv_money_low': 'कमी',
    'lv_money_medium': 'मध्यम',
    'lv_money_high': 'जास्त',
    'lv_loc_gps': 'माझे सध्याचे ठिकाण वापरा',
    'lv_loc_manual': 'निर्देशांक टाइप करा',
    'lv_loc_village': 'माझ्या गावाचा मध्य वापरा',
    'lv_loc_village_note':
        'अहवाल तुमच्या जमिनीपासून नव्हे, तर गावाच्या मध्यापासून मोजला जाईल.',
    'lv_lat': 'अक्षांश',
    'lv_lng': 'रेखांश',
    'lv_loc_default': 'डीफॉल्ट निर्देशांक वापरा',
    'lv_loc_default_note':
        '19.7805, 73.2210 भरले जाते: त्र्यंबक जवळचे नमुना गाव, ज्याच्याभोवती डेमो माहिती बनवली आहे.',
    'lv_loc_getting': 'तुमचे ठिकाण शोधत आहे',
    'lv_loc_got': 'ठिकाण सापडले: {lat}, {lng}',
    'lv_loc_accuracy': 'सुमारे {acc} मी अचूक',
    'lv_loc_denied':
        'स्थानाची परवानगी नाकारली गेली. निर्देशांक टाइप करा किंवा गावाचा मध्य वापरा.',
    'lv_loc_denied_forever':
        'या अॅपसाठी स्थान बंद आहे. फोनच्या सेटिंगमध्ये ते चालू करा, किंवा निर्देशांक टाइप करा.',
    'lv_loc_off':
        'या फोनवर स्थान बंद आहे. ते चालू करा, किंवा निर्देशांक टाइप करा.',
    'lv_loc_failed':
        'तुमचे ठिकाण सापडले नाही. पुन्हा प्रयत्न करा, किंवा निर्देशांक टाइप करा.',
    'lv_err_outside_mh': 'हे ठिकाण महाराष्ट्राबाहेर आहे. संख्या तपासा.',
    'lv_err_coords': 'अक्षांश आणि रेखांश दोन्ही भरा.',
    'lv_save_failed': 'तुमची माहिती जतन करता आली नाही. पुन्हा प्रयत्न करा.',
    'lv_showing_saved':
        'तुमचा शेवटचा जतन केलेला अहवाल दाखवत आहे. तो आत्ता ताजा करता आला नाही.',
    'lv_sync_pending':
        'या फोनवर जतन केले आहे. इंटरनेट मिळाल्यावर ते पाठवले जाईल.',
    'lv_err_offline':
        'आत्ता इंटरनेट नाही. इंटरनेट मिळाल्यावर पुन्हा प्रयत्न करा.',
    'lv_err_signin': 'तुमचा अहवाल पाहण्यासाठी कृपया पुन्हा साइन इन करा.',
    'lv_err_role': 'हा भाग गावकरी आणि ग्रामसभा सदस्यांसाठी आहे.',
    'lv_err_no_village':
        'तुमचे खाते अजून गावाशी जोडलेले नाही. ग्रामसभा कार्यालयाला विचारा.',
    'lv_err_data':
        'साधनांची माहिती अजून तयार नाही. कृपया नंतर पुन्हा प्रयत्न करा.',
    'lv_err_radius': 'हे अंतर चालत नाही. १० किमी पर्यंत वापरा.',
    'lv_err_server':
        'सर्व्हरमध्ये अडचण आली. कृपया थोड्या वेळाने पुन्हा प्रयत्न करा.',
    'lv_err_generic': 'काहीतरी चुकले. कृपया पुन्हा प्रयत्न करा.',
    'w_paddy': 'भात',
    'w_millets': 'नाचणी, वरी',
    'w_pulses': 'कडधान्ये',
    'w_vegetables': 'भाजीपाला',
    'w_fruit': 'फळे',
    'w_dairy': 'दुग्धव्यवसाय',
    'w_goat_rearing': 'शेळीपालन',
    'w_poultry': 'कोंबडीपालन',
    'w_forest_produce': 'वनोपज',
    'w_labour': 'मजुरी',
    'w_other': 'इतर',
    'lv_sec_resources': '{radius_km} किमी परिसरातील साधने',
    'lv_sec_own': 'तुमच्याकडे आधीच काय आहे',
    'lv_sec_heading': 'तुम्ही कोणत्या दिशेने जात आहात',
    'lv_sec_ideas': 'तुमच्यासाठी कल्पना',
    'lv_sec_build_on': 'तुमच्या कामावर आधारित',
    'lv_sec_other': 'इतर पर्याय',
    'lv_sec_why_not': 'इतर का नाहीत?',
    'lv_sec_weather': 'तुमच्या भागातील हवामान',
    'lv_sec_strengths': 'तुम्हाला मदत होईल',
    'lv_sec_constraints': 'लक्ष ठेवा',
    'lv_sec_next': 'पुढील पावले',
    'lv_from_plot': 'तुमच्या जमिनीपासून मोजले',
    'lv_from_village': 'तुमच्या गावाच्या मध्यापासून मोजले',
    'lv_report_for': '{name} यांच्यासाठी',
    'lv_useful': 'उपयुक्त',
    'lv_partly_useful': 'अंशतः उपयुक्त',
    'lv_not_useful': 'उपयुक्त नाही',
    'lv_all': 'सर्व',
    'lv_fit_good': 'चांगला जुळतो',
    'lv_fit_fair': 'बऱ्यापैकी जुळतो',
    'lv_fit_weak': 'कमी जुळतो',
    'lv_wildlife_low': 'वन्यजीव धोका: कमी',
    'lv_wildlife_medium': 'वन्यजीव धोका: मध्यम',
    'lv_wildlife_needs_permission': 'वन विभागाची परवानगी लागेल',
    'lv_cost_low': 'कमी खर्च',
    'lv_cost_medium': 'मध्यम खर्च',
    'lv_cost_high': 'जास्त खर्च',
    'lv_season_year_round': 'वर्षभर',
    'lv_season_kharif': 'खरीप',
    'lv_season_rabi': 'रब्बी',
    'lv_season_summer': 'उन्हाळा',
    'lv_season_post_monsoon': 'पावसानंतर',
    'lv_tag_inside_cfr': 'सामूहिक वन',
    'lv_tag_inside_village': 'तुमच्या गावात',
    'lv_tag_near': 'जवळ',
    'lv_gram_sabha_only': 'फक्त ग्रामसभेमार्फत वापरा',
    'lv_told_by_you': 'तुम्ही सांगितले, पडताळलेले नाही',
    'lv_to_verify': 'प्रत्यक्ष जागेवर पडताळणी बाकी',
    'lv_confirmed': 'समितीने पडताळले',
    'lv_not_checked': 'अजून प्रत्यक्ष तपासलेले नाही',
    'lv_source': 'स्रोत',
    'lv_date_unknown': 'तारीख माहीत नाही',
    'lv_sample': 'नमुना',
    'lv_sample_note': 'ही प्रदर्शनासाठी नमुना माहिती आहे. ही खरी ठिकाणे नाहीत.',
    'lv_draft_idea': 'मसुदा कल्पना, तज्ज्ञांनी तपासलेली नाही',
    'lv_footer': 'फक्त सूचना. प्रत्यक्ष जागेवर तपासा. निर्णय ग्रामसभा घेते.',
    'lv_policy_link': 'आमचे धोरण वाचा',
    'lv_policy_title': 'वन्यजीव धोरण',
    'lv_policy_body':
        'वनमित्र शिकार, सापळे लावणे, वन्यजीव किंवा त्यांच्या अवयवांची विक्री, किंवा प्राण्यांना व त्यांच्या अधिवासाला हानी पोहोचवणाऱ्या कोणत्याही कृतीला पाठिंबा देत नाही.',
    'lv_policy_check':
        'संरक्षित क्षेत्राजवळील कल्पना आधी वन विभागाकडून तपासून घ्याव्यात. आमचे नकाशा स्तर अपूर्ण असल्याने आम्ही "सुरक्षित" नव्हे, तर "वन विभागाकडे तपासा" असे म्हणतो.',
    'lv_no_resources':
        'आमच्या माहितीत {radius_km} किमी परिसरात साधने आढळली नाहीत. याचा अर्थ ती नाहीतच असा नाही.',
    'lv_no_ideas':
        'अजून दाखवण्यासाठी कल्पना नाहीत. तुम्हाला जुळणाऱ्या कल्पनांसाठी तुमची माहिती भरा.',
    'lv_weather_note': 'मागील वर्षांनुसार सामान्य स्थिती. हा अंदाज नाही.',
    'lv_weather_rain': 'पाऊस (मिमी)',
    'lv_disasters_none':
        'आमच्या माहितीत भूतकाळातील आपत्तीची नोंद आढळली नाही. याचा अर्थ घटना झाल्या नाहीत असा नाही.',
    'lv_held_back': 'मागे ठेवली: इतर कल्पना तुम्हाला अधिक जुळतात',
    'lv_gate_removed': 'वगळली: {why}',
    'a_cow': 'गाय',
    'a_buffalo': 'म्हैस',
    'a_bullock': 'बैल',
    'a_goat_sheep': 'शेळी किंवा मेंढी',
    'a_poultry': 'कोंबड्या',
    'a_other': 'इतर जनावरे',
    's_well': 'विहीर',
    's_borewell': 'बोअरवेल',
    's_farm_pond': 'शेततळे',
    's_shed': 'शेड',
    's_pump': 'पंप',
    's_drip_kit': 'ठिबक संच',
    's_bullock_cart': 'बैलगाडी',
    's_storage_room': 'साठवणुकीची खोली',
    's_vehicle': 'वाहन',
    's_fodder_land': 'चाऱ्याची जमीन',
    's_other': 'इतर',
    'k_water_body': 'तलाव किंवा टाके',
    'k_well': 'विहीर',
    'k_water_structure': 'बंधारा किंवा शेततळे',
    'k_river': 'नदी',
    'k_drainage_line': 'ओढा',
    'k_forest_compartment': 'जंगल',
    'k_conservation_reserve': 'संवर्धन राखीव क्षेत्र',
    'k_wildlife_compartment': 'वन्यजीव क्षेत्र',
    'k_grazing_land': 'चराई जमीन',
    'reason.water_dry': 'वर्षातील बहुतेक काळ कोरडे',
    'reason.silted': 'गाळ साचला आहे',
    'reason.poor_condition': 'स्थिती खराब आहे',
    'reason.low_water_months': 'फक्त {months} महिने पाणी असते',
    'reason.far_from_you': 'तुमच्यापासून दूर: {distance_m_fmt}',
    'reason.not_checked': 'याबद्दल अजून काहीही तपासलेले नाही',
    'reason.good_all_round': 'पाणी आहे आणि स्थिती चांगली आहे',
    'reason.good_on_what_is_known': 'आमच्या माहितीनुसार चांगले दिसते',
    'reason.not_fully_checked': 'फक्त अंशतः तपासले आहे',
    'reason.held_back_lower_fit': 'इतर कल्पना तुम्हाला अधिक जुळतात',
    'gate.land_sale_or_lease':
        'जमीन विकता किंवा भाड्याने देता येत नाही (वन हक्क कायदा कलम ४(४))',
    'gate.hunting_or_trapping':
        'शिकार आणि सापळे लावणे मान्य नाही (कलम ३(१)(ल))',
    'gate.timber_or_harm': 'लाकूडतोड किंवा वन्यजीवांना हानी मान्य नाही (कलम ५)',
    'gate.not_allowed_in_cfr': 'सामूहिक वनात मान्य नाही',
    'idea.reason.missing_need': 'जवळ {need} लागते, पण आम्हाला ते सापडले नाही',
    'idea.reason.animals_and_resources':
        'तुमच्याकडे जनावरे आहेत आणि त्यांना लागणारे पाणी व चारा जवळ आहे',
    'idea.reason.matches_past_work': 'तुम्ही पूर्वी केलेल्या कामाशी जुळते',
    'idea.reason.community_resource': 'जवळच्या सामूहिक साधनाचा वापर होतो',
    'idea.reason.good_resources_nearby': 'लागणारी साधने जवळ आहेत',
    'idea.reason.fits_basic':
        'तुम्हाला जुळू शकते; तपासण्यासाठी तुमची माहिती भरा',
    'flag.through_gram_sabha': 'फक्त ग्रामसभेमार्फत वापरा',
    'flag.group_only': 'फक्त ग्रामसभेमार्फत गटाने करता येते',
    'flag.ask_forest_dept': 'आधी वन विभागाला विचारा',
    'flag.possible_flood_risk': 'तुमच्या जवळ पुराचा संभाव्य धोका',
    'flag.hot_area_water_need': 'उष्ण भाग: खूप पाणी लागते',
    'flag.missing_need': 'कमी आहे: {need}',
    'flag.land_unknown': 'सुमारे {min_ha} हेक्टर लागते; तुमची जमीन सांगा',
    'flag.needs_more_land':
        'सुमारे {min_ha} हेक्टर लागते; तुम्ही {have_ha} हेक्टर दिले',
    'analysis.headline.livestock':
        'तुमची जनावरे आणि जवळचे पाणी पशुपालनाकडे निर्देश करतात',
    'analysis.headline.well':
        'हाताशी असलेले पाणी भाजीपाला व रोपवाटिकेकडे निर्देश करते',
    'analysis.headline.mushroom': 'लहान शेडमध्ये अळिंबी शेती सुरू करता येईल',
    'analysis.headline.farm_land':
        'तुमची जमीन शेतीच्या कल्पनांकडे निर्देश करते',
    'analysis.headline.forest_produce': 'जवळचे जंगल वनोपजाकडे निर्देश करते',
    'analysis.headline.grazing': 'जवळची चराई जमीन चारा कामाकडे निर्देश करते',
    'analysis.headline.pond_dam_tank':
        'जवळचा तलाव गटाने मत्स्यपालनाकडे निर्देश करतो',
    'analysis.headline.community_forest':
        'जवळचे सामूहिक वन ग्रामसभेमार्फत वन कामाकडे निर्देश करते',
    'analysis.headline.generic':
        'तुम्ही कोणत्या दिशेने जात आहात हे पाहण्यासाठी तुमची माहिती भरा',
    'analysis.water_nearby':
        '{radius_km} किमी परिसरात {count} पाण्याचे स्रोत; सर्वात जवळचा {nearest_m_fmt} अंतरावर',
    'analysis.own_water_source': 'तुमच्याकडे स्वतःचा पाण्याचा स्रोत आहे',
    'analysis.no_water_nearby':
        'आमच्या माहितीत {radius_km} किमी परिसरात पाण्याचा स्रोत आढळला नाही',
    'analysis.grazing_nearby': 'चराई जमीन {nearest_m_fmt} अंतरावर आहे',
    'analysis.forest_nearby': 'जवळ जंगल ({count})',
    'analysis.forest_nearby_gs':
        'जवळ जंगल ({count}); ते फक्त ग्रामसभेमार्फत वापरा',
    'analysis.water_is_seasonal': 'जवळचे पाणी वर्षाचा काही काळच टिकते',
    'analysis.possible_flood_risk': 'तुमच्या जमिनीला पुराचा धोका असू शकतो',
    'analysis.near_protected_area':
        'संरक्षित क्षेत्र {nearest_m_fmt} अंतरावर आहे',
    'analysis.ask_forest_dept': 'सुरू करण्यापूर्वी वन विभागाला विचारा',
    'analysis.you_have_animals': 'तुमच्याकडे: {list}',
    'analysis.you_have_assets': 'तुमच्याकडे आहे: {list}',
    'analysis.your_land': 'तुमची जमीन: सुमारे {area_ha} हेक्टर',
    'analysis.no_fodder_nearby':
        'तुमच्या जनावरांसाठी {radius_km} किमी परिसरात चराई जमीन आढळली नाही',
    'analysis.verify_with_frc':
        'वन हक्क समितीला हे प्रत्यक्ष जागेवर तपासायला सांगा',
    'analysis.add_details': 'हा अहवाल सुधारण्यासाठी तुमची माहिती भरा',
    'note.profile_incomplete':
        'तुम्ही अजून माहिती भरलेली नाही, म्हणून ही यादी सर्वसाधारण आहे.',
    'note.land_area_missing':
        'कोणत्या कल्पना जुळतात ते तपासण्यासाठी तुमच्या जमिनीचे क्षेत्र भरा.',
    'note.from_village_centre':
        'गावाच्या मध्यापासून मोजले आहे. अधिक अचूक अहवालासाठी तुमची जमीन नकाशावर निवडा.',
    'note.market_not_checked': 'बाजारपेठेची उपलब्धता अजून तपासलेली नाही.',
    'note.dataset_is_sample':
        'हा अहवाल नमुना माहितीवर आधारित आहे, खऱ्या सर्वेक्षणावर नाही.',
    'note.no_resources_found': 'या ठिकाणाजवळ साधने आढळली नाहीत.',
    'note.fewer_than_five': 'पाचपेक्षा कमी कल्पना तपासण्यांमधून पुढे आल्या.',
    // Ask about your report (machine draft: needs a native-speaker review)
    'ask.title': 'तुमच्या अहवालाबद्दल विचारा',
    'ask.entry': 'तुमच्या अहवालाबद्दल विचारा',
    'ask.entry_sub':
        'प्रश्न विचारा. उत्तरे फक्त तुमच्या स्वतःच्या अहवालातून मिळतात.',
    'ask.intro':
        'तुमच्या स्वतःच्या अहवालाबद्दल प्रश्न विचारा. मी फक्त त्यात असलेल्या माहितीवरून उत्तर देऊ शकतो.',
    'ask.hint': 'तुमचा प्रश्न लिहा',
    'ask.send': 'पाठवा',
    'ask.thinking': 'तुमच्या अहवालात पाहत आहे',
    'ask.suggestions': 'तुम्ही हे विचारू शकता',
    'ask.clear': 'माझे प्रश्न हटवा',
    'ask.clear_title': 'तुमचे प्रश्न हटवायचे?',
    'ask.clear_body':
        'तुम्ही विचारलेले प्रश्न आणि त्यांची उत्तरे हटवली जातील. तुमचा अहवाल राहील. हे परत करता येणार नाही.',
    'ask.clear_confirm': 'हटवा',
    'ask.cleared': 'तुमचे प्रश्न हटवले आहेत.',
    'ask.from': 'स्रोत: {parts}',
    'ask.part.summary': 'तुमचा सारांश',
    'ask.part.ideas': 'तुमच्या कल्पना',
    'ask.part.resources': 'तुमच्या जवळची साधने',
    'ask.part.removed': 'वगळलेल्या कल्पना',
    'ask.part.weather': 'हवामान',
    'ask.part.your_details': 'तुम्ही सांगितलेली माहिती',
    'ask.sample_note': 'नमुना माहितीवर आधारित, खऱ्या सर्वेक्षणावर नाही.',
    'ask.question_not_kept': 'प्रश्न जतन केलेला नाही',
    'ask.refused_harmful':
        'आमच्या धोरणानुसार हे चालत नाही. वनमित्र वन्यजीवांना कोणत्याही प्रकारे इजा करण्यास पाठिंबा देत नाही.',
    'ask.off_topic':
        'मी फक्त तुमच्या अहवालाबद्दलच्या प्रश्नांची उत्तरे देऊ शकतो.',
    'ask.not_in_report':
        'हे तुमच्या अहवालात नाही. कृपया कृषी अधिकारी किंवा वन विभागाला विचारा.',
    'ask.nir.outside':
        'बाजारभाव, कर्ज, विमा, पिकांचे प्रश्न आणि प्राण्यांचे हल्ले तुमच्या अहवालात येत नाहीत.',
    'ask.nir.schemes':
        'सरकारी योजना अजून तुमच्या अहवालात नाहीत. कृषी अधिकाऱ्यांना विचारा.',
    'ask.nir.idea_unchecked':
        'ही कल्पना तुमच्या जमिनीसाठी तपासलेली नाही. पैसे गुंतवण्यापूर्वी तज्ज्ञांना विचारा.',
    'ask.nir.idea_not_shown':
        'ही कल्पना तुमच्यासाठी दाखवलेली नाही, म्हणून ती तुमच्या अहवालात नाही.',
    'ask.nir.no_ideas':
        'तुमच्या अहवालात अजून कल्पना नाहीत. कल्पनांसाठी तुमची माहिती भरा.',
    'ask.top_ideas': 'तुमच्या पहिल्या {count} कल्पना',
    'ask.item.idea': '{rank}. {name}: {fit_text}',
    'ask.idea.in_report':
        '{name} तुमच्या अहवालात क्रमांक {rank} वर आहे: {fit_text}',
    'ask.idea.removed_by_gate': '{name} वगळले आहे. {gate_text}',
    'ask.idea.held_back':
        '{name} मागे ठेवले आहे, कारण इतर कल्पना तुम्हाला जास्त जुळतात.',
    'ask.item.cost': '{cost_text}',
    'ask.item.season': 'सर्वोत्तम हंगाम: {season_text}',
    'ask.item.wildlife': '{wildlife_text}',
    'ask.item.idea_wildlife': '{name}: {wildlife_text}',
    'ask.item.idea_cost': '{name}: {cost_text}',
    'ask.item.idea_gram_sabha': '{name}: फक्त ग्रामसभेमार्फत वापरा',
    'ask.item.removed': '{name}: {gate_text}',
    'ask.item.held_back': '{name}: इतर कल्पना तुम्हाला जास्त जुळतात',
    'ask.water.header': '{radius_km} किमी मधील पाणी',
    'ask.item.resource':
        '{name}: {kind_text}, {distance_m_fmt} अंतरावर, {label_text}',
    'ask.resources.header':
        '{radius_km} किमी मध्ये {total} साधने: {useful} उपयुक्त, {partly_useful} अंशतः उपयुक्त, {not_useful} उपयुक्त नाही',
    'ask.wildlife.near':
        'तुमच्या जमिनीजवळ संरक्षित क्षेत्र आहे. आधी वन विभागाला विचारा.',
    'ask.wildlife.none_found':
        'आमच्या माहितीत तुमच्या जमिनीजवळ संरक्षित क्षेत्र आढळले नाही. याचा अर्थ ते नाही असा नाही. शंका असल्यास वन विभागाला विचारा.',
    'ask.flood.possible': 'तुमच्या जमिनीला पुराचा धोका असू शकतो.',
    'ask.flood.none_found':
        'आमच्या माहितीत पुराचा धोका आढळला नाही. याचा अर्थ तो नाही असा नाही.',
    'ask.weather.header':
        'तुमच्या भागातील सर्वसाधारण हवामान, मागील वर्षांवरून. हा अंदाज नाही.',
    'ask.weather.hottest':
        'सर्वात उष्ण महिना: {month_name}, सुमारे {tmax_c} °C',
    'ask.weather.wettest':
        'सर्वात जास्त पावसाचा महिना: {month_name}, सुमारे {rain_mm} मिमी पाऊस',
    'ask.weather.driest':
        'सर्वात कमी पावसाचा महिना: {month_name}, सुमारे {rain_mm} मिमी पाऊस',
    'ask.cost.header': 'तुमच्या पहिल्या कल्पना सुरू करण्याचा खर्च',
    'ask.forest.header': 'तुमच्या जवळचे जंगल',
    'ask.forest.none_found':
        'आमच्या माहितीत तुमच्या जवळ जंगल आढळले नाही. याचा अर्थ ते नाही असा नाही.',
    'ask.own.header': 'तुम्ही सांगितलेली माहिती',
    'ask.own.none':
        'तुम्ही अजून जमीन, प्राणी किंवा तुमच्याकडे काय आहे ते सांगितलेले नाही. ते येथे दिसण्यासाठी माहिती भरा.',
    'ask.removed.header': '{count} कल्पना तुमच्या पहिल्या यादीत नाहीत',
    'ask.removed.none': 'तुमच्या अहवालातून कोणत्याही कल्पना वगळलेल्या नाहीत.',
    'ask.schemes.header':
        'तुमच्या कल्पनांशी संबंधित असू शकणाऱ्या योजना. आम्ही फक्त अधिकृत पानांची लिंक देतो आणि तुम्ही पात्र आहात की नाही हे सांगू शकत नाही.',
    'ask.item.idea_schemes': '{name}: {count} योजना संबंधित असू शकतात',
    'ask.chip.schemes': 'कोणत्या योजना मदत करू शकतात?',
    'ask.ai_consent_title': 'इतर प्रश्नांची उत्तरे एआय सहाय्यकाने द्यावीत का?',
    'ask.ai_consent_body':
        'आमची स्वतःची उत्तरे ज्या प्रश्नांना पुरत नाहीत, त्यासाठी एआय सहाय्यक तुमच्या अहवालातील तथ्ये वाचू शकतो. आम्ही तुमचे नाव किंवा तुमच्या जमिनीचे नेमके ठिकाण कधीही पाठवत नाही. तुम्ही लिहिलेला प्रश्न मात्र पाठवला जातो, म्हणून तुमचे नाव किंवा फोन नंबर लिहू नका. त्याची उत्तरे तुमच्या अहवालाशी तपासली जातात, तरीही कृपया ती स्वतः तपासा.',
    'ask.ai_allow': 'परवानगी द्या',
    'ask.ai_deny': 'आत्ता नको',
    'ask.ai_toggle': 'एआय सहाय्यक माझ्या अहवालातील तथ्ये वाचू शकतो',
    'ask.ai_label':
        'तुमच्या अहवालावरून एआय सहाय्यकाने लिहिले. कृपया ते स्वतः तपासा.',
    'ask.ai_answer': 'एआय सहाय्यकाचे उत्तर',
    'ask.chip.heading': 'मी कोणत्या दिशेने जात आहे?',
    'ask.chip.top_ideas': 'माझ्या सर्वोत्तम कल्पना कोणत्या?',
    'ask.chip.idea': '{name} बद्दल सांगा',
    'ask.chip.water': 'माझ्या जवळ पाणी आहे का?',
    'ask.chip.wildlife': 'माझ्या जवळ संरक्षित क्षेत्र आहे का?',
    'ask.chip.cost': 'माझ्या कल्पनांना किती खर्च येईल?',
    'ask.chip.forest': 'माझ्या जवळच्या जंगलाचे काय?',
    'ask.chip.own': 'मी तुम्हाला काय सांगितले होते?',
    'ask.chip.weather': 'हवामान कसे आहे?',
    'ask.chip.removed': 'इतर कल्पना का वगळल्या?',
    'm_1': 'जानेवारी',
    'm_2': 'फेब्रुवारी',
    'm_3': 'मार्च',
    'm_4': 'एप्रिल',
    'm_5': 'मे',
    'm_6': 'जून',
    'm_7': 'जुलै',
    'm_8': 'ऑगस्ट',
    'm_9': 'सप्टेंबर',
    'm_10': 'ऑक्टोबर',
    'm_11': 'नोव्हेंबर',
    'm_12': 'डिसेंबर',
    // Idea detail and schemes (machine draft: needs a native-speaker review)
    'idea.title': 'कल्पनेचा तपशील',
    'idea.rank': 'तुमच्या अहवालात क्रमांक {rank}',
    'idea.status_removed': 'सुचवलेली नाही: कायद्याची तपासणी ती थांबवते',
    'idea.status_held_back': 'मागे ठेवली: इतर कल्पना तुम्हाला जास्त जुळतात',
    'idea.why': 'ही कल्पना का',
    'idea.needs': 'यासाठी काय लागते',
    'idea.need_met_own': 'तुमच्याकडे आहे: {what}',
    'idea.need_met_near': 'तुमच्या जवळ आढळले: {what}',
    'idea.need_missing': 'आढळले नाही: {what}',
    'idea.or': ' किंवा ',
    'idea.checks': 'केलेल्या तपासण्या',
    'idea.check.passed': 'उत्तीर्ण',
    'idea.check.flagged': 'याकडे लक्ष द्या',
    'idea.check.not_checked': 'अजून तपासलेले नाही',
    'idea.check_name.law': 'कायदा',
    'idea.check_name.wildlife': 'वन्यजीव',
    'idea.check_name.needs': 'यासाठी काय लागते',
    'idea.check_name.land': 'जमीन',
    'idea.check_name.community': 'सामुदायिक वन',
    'detail.check.law':
        'चारही कायदेशीर तपासण्या ही कल्पना पार करते. हा कायदेशीर सल्ला नाही; निर्णय ग्रामसभा घेते.',
    'detail.check.wildlife_low':
        'वन्यजीव धोका कमी. शंका असल्यास वन विभागाला विचारा.',
    'detail.check.wildlife_medium':
        'वन्यजीव धोका मध्यम. सुरू करण्यापूर्वी वन विभागाला विचारा.',
    'detail.check.wildlife_needs_permission':
        'सुरू करण्यापूर्वी वन विभागाची परवानगी लागते.',
    'detail.check.needs_met':
        'यासाठी लागणारे तुमच्या जवळ आहे, किंवा आधीच तुमचे आहे.',
    'detail.check.needs_missing': 'यासाठी लागणारे काही तुमच्या जवळ आढळले नाही.',
    'detail.check.land_ok': 'या कल्पनेसाठी तुमची जमीन पुरेशी आहे.',
    'detail.weather.flood_risk':
        'तुमच्या जमिनीला पूर येऊ शकतो. पावसाळ्याच्या महिन्यांसाठी नियोजन करा.',
    'detail.weather.heat':
        'या कल्पनेसाठी उन्हात काळजी लागते. तुमच्या भागातील सर्वात उष्ण महिना {month_name}, सुमारे {tmax_c} °C.',
    'detail.weather.typical':
        'तुमच्या भागातील सर्वसाधारण हवामान तुमच्या अहवालात आहे. हा अंदाज नाही.',
    'idea.resources': 'यासाठी वापरता येणारी साधने',
    'idea.warnings': 'लक्षात ठेवा',
    'idea.weather': 'हवामानाची टीप',
    'idea.schemes': 'संबंधित असू शकणाऱ्या योजना',
    'idea.schemes_note':
        'आम्ही फक्त अधिकृत पानांची लिंक देतो. तुम्ही पात्र आहात की नाही हे आम्ही सांगू शकत नाही.',
    'idea.schemes_none': 'या कल्पनेसाठी अजून योजना नोंदवलेल्या नाहीत.',
    'idea.see_all_schemes': 'सर्व योजना पहा',
    'idea.schemes_count': '{count} योजना संबंधित असू शकतात',
    'idea.open': 'तपशील पहा',
    'sch.title': 'योजना',
    'sch.entry': 'सरकारी आणि स्वयंसेवी संस्थांच्या योजना',
    'sch.entry_sub': 'अधिकृत पानांच्या लिंक. आम्ही अर्ज घेत नाही.',
    'sch.tab_government': 'सरकारी',
    'sch.tab_ngo': 'स्वयंसेवी संस्था',
    'sch.filter_help': 'मदतीचा प्रकार',
    'sch.filter_who': 'कोणासाठी',
    'sch.filter_all': 'सर्व',
    'sch.help.farming': 'शेती',
    'sch.help.fishing': 'मत्स्यव्यवसाय',
    'sch.help.livestock': 'पशुपालन',
    'sch.help.small_business': 'लघु उद्योग',
    'sch.help.forest_produce': 'वनउपज',
    'sch.aud.women': 'महिला',
    'sch.aud.tribal': 'आदिवासी समुदाय',
    'sch.aud.farmers': 'शेतकरी',
    'sch.aud.groups': 'गट',
    'sch.runs': 'चालवणारे: {who}',
    'sch.who': 'कोण अर्ज करू शकतो',
    'sch.documents': 'सहसा मागितली जाणारी कागदपत्रे',
    'sch.last_checked': 'शेवटची तपासणी: {date}',
    'sch.never_checked': 'अजून कोणा व्यक्तीने तपासलेली नाही',
    'sch.open': 'अधिकृत पान उघडा',
    'sch.no_page': 'अधिकृत पान अजून जोडलेले नाही',
    'sch.open_failed': 'पान उघडता आले नाही. नंतर पुन्हा प्रयत्न करा.',
    'sch.empty_register': 'अजून कोणत्याही योजना जोडलेल्या नाहीत.',
    'sch.empty_filter': 'या निवडीशी जुळणारी योजना नाही.',
    'sch.disclaimer':
        'आम्ही फक्त अधिकृत पानांची लिंक देतो. आम्ही अर्ज घेत नाही आणि तुम्ही पात्र आहात की नाही हे सांगू शकत नाही. नियम आणि रक्कम अधिकृत पानावर वाचा.',
    'sch.sample_note': 'डेमोसाठी नमुना नोंदी. ह्या खऱ्या योजना नाहीत.',
  },
};

class LivelihoodStrings {
  const LivelihoodStrings(this.lang);

  /// A language code: en, mr, hi ... Missing text falls back to English, never to a blank.
  final String lang;

  static LivelihoodStrings of(BuildContext context) =>
      LivelihoodStrings(Localizations.localeOf(context).languageCode);

  String _raw(String key) => _text[lang]?[key] ?? _text['en']![key] ?? key;

  /// A plain UI string with `{name}` placeholders filled from [params].
  String t(String key, [Map<String, Object?> params = const {}]) {
    var out = _raw(key);
    params.forEach((name, value) {
      out = out.replaceAll('{$name}', '$value');
    });
    return out;
  }

  /// "420 m" or "2.1 km".
  static String distance(num metres) => metres >= 1000
      ? '${(metres / 1000).toStringAsFixed(1)} km'
      : '${metres.round()} m';

  /// Radius in km for headings: 5000 -> "5".
  static String km(num metres) {
    final v = metres / 1000;
    return v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
  }

  String animal(String code) => t('a_$code');
  String asset(String code) => t('s_$code');
  String kind(String code) => t('k_$code');

  /// A need code ('well', 'asset:pump') as words in this language.
  String needName(String code) => _need(code);

  String _need(Object? need) {
    final code = '$need';
    return switch (code) {
      final c when c.startsWith('asset:') => asset(c.substring(6)),
      final c when _text['en']!.containsKey('k_$c') => kind(c),
      final c => c,
    };
  }

  /// Turn a server {key, params} into a sentence in this language.
  String reason(Reason r) {
    final params = Map<String, Object?>.from(r.params);

    // distances arrive in metres; show them as "420 m" / "2.1 km"
    for (final name in r.params.keys.toList()) {
      final value = r.params[name];
      if (name.endsWith('_m') && value is num) {
        params['${name}_fmt'] = distance(value);
        params[name] = value.round();
      }
    }
    if (params['radius_m'] is num) {
      params['radius_km'] = km(params['radius_m'] as num);
    }
    if (params['need'] != null) params['need'] = _need(params['need']);
    _askParams(params);

    var key = r.key;
    if (key == 'analysis.you_have_animals') {
      params['list'] = r.params.entries
          .where((e) => e.value is num)
          .map((e) => '${animal(e.key)} ${e.value}')
          .join(', ');
    } else if (key == 'analysis.you_have_assets') {
      final assets = (r.params['assets'] as List?) ?? const [];
      params['list'] = assets.map((a) => asset('$a')).join(', ');
    } else if (key == 'analysis.forest_nearby' &&
        r.params['gram_sabha_only'] == true) {
      key = 'analysis.forest_nearby_gs';
    }
    if (key == 'ask.item.removed' && r.params['gate'] == null) {
      key =
          'ask.item.held_back'; // held back for a lower fit, not removed by a law
    }
    return t(key, params);
  }

  /// The facts an Ask answer carries as codes (names, fit, cost ...) written in this language.
  void _askParams(Map<String, Object?> params) {
    final nameEn = params['name_en'];
    final nameMr = params['name_mr'];
    if (nameEn != null || nameMr != null) {
      final preferred = lang == 'mr' ? nameMr : nameEn;
      params['name'] = (preferred ?? nameEn ?? nameMr).toString();
    }
    String? lookup(String prefix, Object? code) =>
        code == null ? null : t('$prefix$code');
    final fit = lookup('lv_fit_', params['fit']);
    if (fit != null) params['fit_text'] = fit;
    final cost = lookup('lv_cost_', params['cost_level']);
    if (cost != null) params['cost_text'] = cost;
    final wildlife = lookup('lv_wildlife_', params['wildlife_risk']);
    if (wildlife != null) params['wildlife_text'] = wildlife;
    final season = lookup('lv_season_', params['season']);
    if (season != null) params['season_text'] = season;
    final label = lookup('lv_', params['label']);
    if (label != null) params['label_text'] = label;
    if (params['kind'] != null) params['kind_text'] = kind('${params['kind']}');
    final gate = params['gate'];
    if (gate != null) params['gate_text'] = t('gate.${'$gate'.toLowerCase()}');
    final month = params['month'];
    if (month is num) params['month_name'] = t('m_${month.round()}');
  }

  /// Notes the server sends as plain codes ("market_not_checked").
  String note(String code) => t('note.$code');

  String labelText(UsefulLabel l) => switch (l) {
        UsefulLabel.useful => t('lv_useful'),
        UsefulLabel.partlyUseful => t('lv_partly_useful'),
        UsefulLabel.notUseful => t('lv_not_useful'),
      };

  String fitText(FitLabel f) => switch (f) {
        FitLabel.good => t('lv_fit_good'),
        FitLabel.fair => t('lv_fit_fair'),
        FitLabel.weak => t('lv_fit_weak'),
      };

  String wildlifeText(Wildlife w) => switch (w) {
        Wildlife.low => t('lv_wildlife_low'),
        Wildlife.medium => t('lv_wildlife_medium'),
        Wildlife.needsPermission => t('lv_wildlife_needs_permission'),
      };

  /// "Source · date · status" for a trust label. An unknown date says so (rule L1).
  String trustLine(TrustLabel trust) {
    final date =
        trust.sourceDate == 'unknown' ? t('lv_date_unknown') : trust.sourceDate;
    final status = trust.isConfirmed ? t('lv_confirmed') : t('lv_to_verify');
    return '${t('lv_source')}: ${trust.source}, $date. $status';
  }
}
