---
section: program
permalink: /program/
title: Our Program
---

# Our Program {#program}

The following sessions have been confirmed so far for {{ page.event_name }}. Thank you to everyone who submitted proposals! We still have a handful of sessions left to finalize, and descriptions here will evolve in the weeks leading up to the event.

<!-- We'll publish the complete schedule with session dates and times soon. -->

**If you're figuring out travel plans:** {{ page.event_name }} will begin around 9am on the first day and closes around 6pm on the second day. Most participants arrive in the afternoon the day before SRCCON starts and head home the morning after it wraps.

Since this is our 15th year as OpenNews, we'll likely be hosting unofficial (i.e. non-SRCCON) events the evening before and the day after the conference — in case you want to hang with the community longer!

### Sessions {#sessions}

Our conference schedule this year will include the sessions below. A huge thank you to the [community panel](#community-review) that helped us during our review process! These community members have the difficult job of parsing dozens of tremendous session pitches we receive to help us surface the essential discussions we need to have at SRCCON. The community and OpenNews team is indebted to them.

<div class="session-proposal-list">
{% for session in site.data.sessions %}
    <div class="session-proposal" id="session-{{ session.id }}">
        <h4 class="session-title"><a href="#session-{{ session.id }}">{{ session.title }}</a></h4>
        {% if session.facilitators %}<p class="facilitator">Facilitated by {{ session.facilitators }}</p>{% endif %}
        <p class="session-description">{{ session.description | markdownify }}</p>
    </div>
{% endfor %}
</div>

<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.3/jquery.min.js"></script>
<script src="/media/js/listfilter.min.js"></script>
<script>
var filter = ListFilter({
    listContainer: '.session-proposal-list',
    filterItemClass: '.session-proposal'
});
</script>

### Community reviewers {#community-review}

We'd also like to thank the folks who helped us select this amazing slate of sessions! Each year's program review includes a panel of community members with a range of experiences and perspectives to make sure SRCCON has sessions that respond to your needs.

Thank you, community reviewers!

- André Natta
- Kai Teoh
- Emilia Ruzicka
- Damon Kiesow
- Kate Travis
- C.J. Sinner
- Justin Myers
