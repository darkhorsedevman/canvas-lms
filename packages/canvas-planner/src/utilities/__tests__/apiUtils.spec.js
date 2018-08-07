/*
 * Copyright (C) 2017 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that they will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */
import moment from 'moment-timezone';
import {
  transformApiToInternalItem,
  transformInternalToApiItem,
  transformInternalToApiOverride,
  transformPlannerNoteApiToInternalItem,
  transformApiToInternalGrade,
} from '../apiUtils';

const courses = [{
  id: '1',
  shortName: 'blah',
  image: 'blah_url',
  color: '#abffaa',
}];
const groups = [{
  id: '9',
  assetString: 'group_9',
  name: 'group9',
  color: '#ffeeee',
  url: '/groups/9'
}];

const addContextInfo = resp =>
  resp.course_id
    ? {
        context_name: `course name for course id ${resp.course_id}`,
        context_image: `https://example.com/course/${resp.course_id}/image`,
        ...resp
      }
    : resp

function makeApiResponse (overrides = {}, assignmentOverrides = {}) {
  return addContextInfo({
    plannable_id: "10",
    context_type: "Course",
    course_id: "1",
    type: "submitting",
    ignore: `/api/v1/users/self/todo/assignment_10/submitting?permanent=0`,
    ignore_permanently: `/api/v1/users/self/todo/assignment_10/submitting?permanent=1`,
    planner_override: null,
    plannable_type: 'assignment',
    plannable: makeAssignment(assignmentOverrides),
    submissions: false,
    new_activity: false,
    plannable_date: '2018-03-27T18:58:51Z',
    ...overrides,
  });
}

function makePlannerNoteApiResponse (overrides = {}) {
  return addContextInfo({
    id: 14,
    todo_date: '2017-06-21T18:58:51Z',
    title: 'abc123',
    details: 'asdfasdfasdf',
    user_id: 5,
    course_id: null,
    workflow_state: 'active',
    created_at: '2017-06-21T18:58:57Z',
    updated_at: '2017-06-21T18:58:57Z',
    ...overrides
  });
}

function makePlannerNote (overrides = {}) {
  return {
    id: 10,
    todo_date: "2017-05-19T05:59:59Z",
    title: "Some To Do Note",
    details: "Some To Do Note Details :)",
    user_id: '1',
    course_id: '1',
    workflow_state: 'active',
    ...overrides
  };
}

function makeAssignment (overrides = {}) {
  return {
    id: "10",
    description: "<p>Lorem ipsum etc.</p>",
    due_at: "2017-05-19T05:59:59Z",
    unlock_at: null,
    lock_at: null,
    points_possible: 100,
    grading_type: "points",
    assignment_group_id: "2",
    grading_standard_id: null,
    created_at: "2017-05-15T14:36:03Z",
    updated_at: "2017-05-15T16:20:35Z",
    peer_reviews: false,
    automatic_peer_reviews: false,
    position: 2,
    grade_group_students_individually: false,
    anonymous_peer_reviews: false,
    group_category_id: null,
    post_to_sis: false,
    moderated_grading: false,
    omit_from_final_grade: false,
    intra_group_peer_reviews: false,
    secure_params: "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9",
    course_id: "1",
    name: "",
    submission_types: [
      "online_text_entry",
      "online_upload"
    ],
    has_submitted_submissions: false,
    due_date_required: false,
    max_name_length: 255,
    in_closed_grading_period: false,
    is_quiz_assignment: false,
    muted: false,
    html_url: `/courses/1/assignments/10`,
    quiz_id: "1",
    anonymous_submissions: false,
    published: true,
    only_visible_to_overrides: false,
    locked_for_user: false,
    submissions_download_url: `/courses/1/quizzes/1/submissions?zip=1`,
    ...overrides,
  };
}

function makeDiscussionTopic (overrides = {}) {
  return {
    id: "1",
    title: "",
    last_reply_at: "2017-05-15T16:32:34Z",
    delayed_post_at: null,
    posted_at: "2017-05-15T16:32:34Z",
    assignment_id: 9,
    root_topic_id: null,
    position: null,
    podcast_has_student_posts: false,
    discussion_type: "side_comment",
    lock_at: null,
    allow_rating: false,
    only_graders_can_rate: false,
    sort_by_rating: false,
    user_name: "clay@instructure.com",
    discussion_subentry_count: 0,
    permissions: {
      attach: false,
      update: false,
      reply: true,
      delete: false
    },
    require_initial_post: null,
    user_can_see_posts: true,
    podcast_url: null,
    read_state: "unread",
    unread_count: 0,
    subscribed: false,
    topic_children: [],
    attachments: [],
    published: true,
    can_unpublish: false,
    locked: false,
    can_lock: false,
    comments_disabled: false,
    author: {
      id: "1",
      display_name: "Carl Chudyk",
      avatar_image_url: "http://canvas.instructure.com/images/messages/avatar-50.png",
      html_url: `/courses/1/users/1`
    },
    html_url: `/courses/1/discussion_topics/10`,
    url: `/courses/1/discussion_topics/10`,
    pinned: false,
    group_category_id: null,
    can_group: true,
    locked_for_user: false,
    message: "<p>Some prompt</p>",
    ...overrides,
  };
}

function makeGradedDiscussionTopic (overrides = {}) {
  return {
    id: "1",
    title: "",
    last_reply_at: "2017-05-15T16:32:34Z",
    delayed_post_at: null,
    posted_at: null,
    assignment_id: 10,
    root_topic_id: null,
    assignment: {due_at: "2017-05-15T16:32:34Z"},
    position: null,
    podcast_has_student_posts: false,
    discussion_type: "side_comment",
    lock_at: null,
    allow_rating: false,
    only_graders_can_rate: false,
    sort_by_rating: false,
    user_name: "clay@instructure.com",
    discussion_subentry_count: 0,
    permissions: {
      attach: false,
      update: false,
      reply: true,
      delete: false
    },
    require_initial_post: null,
    user_can_see_posts: true,
    podcast_url: null,
    read_state: "unread",
    unread_count: 0,
    subscribed: false,
    topic_children: [],
    attachments: [],
    published: true,
    can_unpublish: false,
    locked: false,
    can_lock: false,
    comments_disabled: false,
    author: {
      id: "1",
      display_name: "Carl Chudyk",
      avatar_image_url: "http://canvas.instructure.com/images/messages/avatar-50.png",
      html_url: `/courses/1/users/1`
    },
    html_url: `/courses/1/discussion_topics/10`,
    url: `/courses/1/discussion_topics/10`,
    pinned: false,
    group_category_id: null,
    can_group: true,
    locked_for_user: false,
    message: "<p>Some prompt</p>",
    ...overrides,
  };
}

function makeWikiPage(overrides = {}) {
  return {
    title: 'wiki_page title',
    created_at: "2017-06-16 10:08:00Z",
    url: 'wiki-page-title',
    editing_roles: 'teachers',
    page_id: '1',
    last_edited_by: {
      id: '1',
      display_name: 'Carl Chudyk',
      avatar_image_url: "http://canvas.instructure.com/images/messages/avatar-50.png",
      html_url: `/courses/1/users/1`,
    },
    published: true,
    hide_from_students: false,
    front_page: false,
    html_url: `/courses/1/pages/wiki-page-title`,
    todo_date: "2017-06-16 10:08:00Z",
    updated_at: "2017-06-16 10:08:00Z",
    locked_for_user: false,
    body: 'body of wiki page',
    ...overrides,
  };
}

function makeCalendarEvent(overrides = {}) {
  return {
    id: 1,
    title: 'calendar_event title',
    created_at: "2018-04-28 00:36:25Z",
    start_at: '2018-05-04 19:00:00Z',
    description: 'calendar event description',
    all_day: false,
    effective_context_code: 'course_1',
    url: '/api/v1/calendar_event/1',
    html_url: '/calendar?event_id=1&include_contexts=course_1',
    todo_date: undefined,
    ...overrides,
  }
}

function makeAssessmentRequest(overrides = {}) {
  return {
    workflow_state: 'assigned'
  }
}

describe('transformApiToInternalItem', () => {
  it('extracts and transforms the proper data for responses containing a status', () => {
    const apiResponse = makeApiResponse({
      submissions: {
        graded: true,
        has_feedback: true
      }
    });

    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');

    expect(result.status).toEqual({
      graded: true,
      has_feedback: true
    });
  });

  it('extracts and transforms the proper data for a quiz response', () => {
    const apiResponse = makeApiResponse({
      plannable_type: 'quiz',
      plannable: makeAssignment({
        name: 'How to make friends',
        submission_types: [ 'online_quiz' ],
        todo_date: undefined,
      })
    });
    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchSnapshot();
  });

  it('extracts and transforms the proper data for a graded discussion response', () => {
    const apiResponse = makeApiResponse({
      plannable_type: 'discussion_topic',
      plannable: makeGradedDiscussionTopic({
        name: 'How to make friends part 2',
        submission_types: [ 'discussion_topic' ],
        todo_date: undefined,
      })
    });
    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchSnapshot();
  });

  it('extracts and transforms the proper data for a discussion response', () => {
    const apiResponse = makeApiResponse({
      plannable_type: 'discussion_topic',
      plannable: makeDiscussionTopic({
        title: "How to make enemies",
        points_possible: 40,
        todo_date: "2017-05-19T05:59:59Z",
      })
    });
    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchSnapshot();
  });

  it('extracts and transforms the proper data for a graded discussion reponse with an unread count', () => {
    const apiResponse = makeApiResponse({
      plannable_type: 'discussion_topic',
      submissions: { submitted: true },
      plannable: makeDiscussionTopic({
        title: "How to make enemies",
        points_possible: 40,
        unread_count: 10,
        todo_date: undefined,
      })
    });
    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchSnapshot();
  });

  it('extracts and transforms the proper data for an ungraded discussion reponse with an unread count', () => {
    const apiResponse = makeApiResponse({
      plannable_type: 'discussion_topic',
      submissions: false,
      plannable: makeDiscussionTopic({
        title: "How to make enemies",
        todo_date: "2017-05-19T05:59:59Z",
        unread_count: 10
      })
    });
    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchSnapshot();
  });

  it("shouldn't show new activity for discussions with a 0 unread count", () => {
    const apiResponse = makeApiResponse({
      plannable_type: 'discussion_topic',
      submissions: false,
      new_activity: true,
      plannable: makeDiscussionTopic({
        title: "How to make enemies",
        todo_date: "2017-05-19T05:59:59Z",
        unread_count: 0
      })
    });
    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchObject({newActivity: false})
  });

  it('extracts and transforms the proper data for an assignment response', () => {
    const apiResponse = makeApiResponse({
      plannable_type: 'assignment',
      plannable: makeAssignment({
        points_possible: 50,
        name: "How to be neutral",
        todo_date: undefined,
      }),
    });
    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchSnapshot();
  });

  it('extracts and transforms the proper data for a planner_note response', () => {
    const apiResponse = makeApiResponse({
      context_type: undefined,
      course_id: undefined,
      plannable_type: 'planner_note',
      plannable: makePlannerNote()
    });

    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchSnapshot();
  });

  it('extracts and transforms the proper data for a planner_note response without an associated course', () => {
    const apiResponse = makeApiResponse({
      context_type: undefined,
      course_id: undefined,
      plannable_type: 'planner_note',
      plannable: makePlannerNote({
        course_id: undefined
      })
    });

    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchSnapshot();
  });

  it('extracts and transforms the ID for a wiki page repsonse', () => {
    const apiResponse = makeApiResponse({
      plannable_type: 'wiki_page',
      plannable: makeWikiPage({}),
    });
    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result.id).toEqual('1');
  });

  it('extracts and transforms the proper data for a calendar event response', () => {
    const apiResponse = makeApiResponse({
      plannable_type: 'calendar_event',
      plannable: makeCalendarEvent()
    });
    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchSnapshot();
  });

  it('extracts and transforms the proper data for a calendar event response with an all day date', () => {
    const apiResponse = makeApiResponse({
      plannable_type: 'calendar_event',
      plannable: makeCalendarEvent({all_day: true})
    });

    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchSnapshot();
  });

  it('extracts and transforms the proper date for a peer review', () => {
    // primarily testing that the internal item pulls its title from the assignment
    const apiResponse = makeApiResponse({
      plannable_type: 'assessment_request',
      plannable: {
        id: '1',
        assignment: makeAssignment({
          name: "review me",
        }),
      },
    });

    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchSnapshot();
  });

  it('adds the dateBucketMoment field', () => {
    const apiResponse = makeApiResponse({
      plannable_type: 'assignment',
      plannable_date: moment.tz('2017-05-24', 'Asia/Tokyo'),
      plannable: makeAssignment({
        due_at: moment.tz('2018-03-28', 'Asia/Tokyo'),
      })
    });
    const result = transformApiToInternalItem(apiResponse, courses, groups, 'Europe/Paris');
    const expectedBucket = moment.tz('2017-05-23', 'Europe/Paris');
    expect(result.dateBucketMoment.isSame(expectedBucket)).toBeTruthy();
  });

  it('handles items without context (notes to self)', () => {
    const apiResponse = makeApiResponse();
    delete apiResponse.context;
    delete apiResponse.context_type;
    delete apiResponse.course_id;
    const result = transformApiToInternalItem(apiResponse, courses, groups, 'Europe/Paris');
    expect(result).toMatchObject({id: '10'});
  });

  it('throws if the timezone parameter is missing', () => {
    expect(() => transformApiToInternalItem({}, [])).toThrow();
  });

  it('copes with a non-existent (e.g. concluded) course', () => {
    const apiResponse = makeApiResponse({
      course_id: 999,
      plannable_type: 'planner_note',
      plannable: makePlannerNote({
        course_id: 999
      })
    });

    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchSnapshot();
  });

  it('handles account-level group items', () => {
    const apiResponse = makeApiResponse({
      "context_type": "Group",
      "group_id": "9",
      "plannable_date": "2018-01-12T05:00:00Z",
      "plannable_type": "wiki_page",
      "plannable": makeWikiPage({page_id: "25", html_url:"/groups/9/pages/25"}),
      "html_url": "/groups/9/pages/25"
    });

    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchSnapshot();
  });

  it('handles feedback', () => {
    const apiResponse = makeApiResponse({
      submissions: {
        feedback: 'hello world'
      }
    });

    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result.feedback).toEqual('hello world');
  });

  it('includes location and endTime if given', () => {
    const apiResponse = makeApiResponse({
      plannable_type: 'calendar_event',
      plannable_date: "2018-01-12T05:00:00Z",
      plannable: makeCalendarEvent({
        end_at: "2018-01-12T07:00:00Z",
        location_name: "A galaxy far far away",
      }),
      dateStyle: "none",
    });
    const result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result).toMatchSnapshot();
  });

  it('sets allDay properly', () => {
    const apiResponse = makeApiResponse({
      plannable_type: 'calendar_event',
      plannable_date: "2018-01-12T05:00:00Z",
      plannable: makeCalendarEvent({
        all_day: true,
      })
    });
    let result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result.allDay).toBeTruthy();

    apiResponse.plannable.all_day = false;
    result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result.allDay).toBeFalsy();
  })

  it('sets completed correctly', () => {
    const apiResponse = makeApiResponse({
      submissions: {
        graded: true,
        has_feedback: true
      }
    });
    // graded => not complete
    let result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result.completed).toBeFalsy();

    // excused => not complete
    apiResponse.submissions.excused = true;
    result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result.completed).toBeFalsy();

    // submitted => complete
    apiResponse.submissions.submitted = true;
    result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result.completed).toBeTruthy();

    // !submitted but user marked complete => complete
    apiResponse.submissions.submitted = false;
    apiResponse.planner_override = {marked_complete: true}
    result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result.completed).toBeTruthy();

    // submitted but user marked not complete => not complete
    apiResponse.submissions.submitted = true;
    apiResponse.planner_override = {marked_complete: false}
    result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result.completed).toBeFalsy();

    // assessment_request (they're different)
    // - assigned => not complete
    apiResponse.plannable = makeAssessmentRequest();
    result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result.completed).toBeFalsy();

    // - assigned with completed override => complete
    apiResponse.planner_override = {marked_complete: true};
    result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result.completed).toBeTruthy();

    // - completed with no override => complete
    apiResponse.plannable.workflow_state = 'completed';
    apiResponse.planner_override = null;
    result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result.completed).toBeTruthy();

    // - completed with incomplete override => not complete
    apiResponse.planner_override = {marked_complete: false};
    result = transformApiToInternalItem(apiResponse, courses, groups, 'UTC');
    expect(result.completed).toBeFalsy();
  })
});

describe('transformInternalToApiItem', () => {
  it('transforms items without a context', () => {
    const internalItem = {
      id: '42',
      date: '2017-05-25',
      title: 'an item',
      details: 'item details',
    };
    const result = transformInternalToApiItem(internalItem);
    expect(result).toMatchObject({
      id: '42',
      todo_date: '2017-05-25',
      title: 'an item',
      details: 'item details',
    });
  });

  it('transforms context information', () => {
    const internalItem = {
      context: {
        id: '42',
      },
    };
    expect(transformInternalToApiItem(internalItem)).toMatchObject({
      context_type: 'Course',
      course_id: '42',
    });
  });
});

describe('transformInternalToApiOverride', () => {
  it('gets override data from an internal item', () => {
    const internalItem = {
      id: '42',
      overrideId: '52',
      type: 'Assignment',
      completed: false
    };
    const result = transformInternalToApiOverride(internalItem, '1');
    expect(result).toMatchObject({
      id: '52',
      plannable_id: '42',
      plannable_type: 'assignment',
      user_id: '1',
      marked_complete: false
    });
  });

  it('graded items should give plannable_id as assignment ID and plannable_type as assignment', () => {
    const internalItem = {
      id: '42',
      overrideId: null,
      type: 'DiscussionTopic',
      overrideAssignId: '10',
      completed: false
    };
    const result = transformInternalToApiOverride(internalItem, '1');
    expect(result).toMatchObject({
      id: null,
      plannable_id: '10',
      plannable_type: 'assignment',
      user_id: '1',
      marked_complete: false
    });
  });

  it('non-graded non-assignment items should give their own ids and types', () => {
    const internalItem = {
      id: '42',
      overrideId: null,
      type: 'Discussion',
      overrideAssignId: null,
      completed: false
    };
    const result = transformInternalToApiOverride(internalItem, '1');
    expect(result).toMatchObject({
      id: null,
      plannable_id: '42',
      plannable_type: 'discussion_topic',
      user_id: '1',
      marked_complete: false
    });
  });
});

describe('transformPlannerNoteApiToInternalItem', () => {
  it('transforms the planner note response to the internal item', () => {
    const apiResponse = makePlannerNoteApiResponse();
    const internalItem = transformPlannerNoteApiToInternalItem(apiResponse, courses, 'UTC');
    expect(internalItem).toMatchSnapshot();
  });

  it('transforms the planner note response to an internal item when the planner note has an associated course', () => {
    const apiResponse = makePlannerNoteApiResponse({ course_id: '1'});
    const internalItem = transformPlannerNoteApiToInternalItem(apiResponse, courses, 'UTC');
    expect(internalItem).toMatchSnapshot();
  });
});

describe('transformApiToInternalGrade', () => {
  it('transforms with grading periods', () => {
    expect(transformApiToInternalGrade({
      id: '42',
      has_grading_periods: true,
      enrollments: [{
        computed_current_score: 34.42,
        computed_current_grade: 'F',
        current_period_computed_current_score: 42.34,
        current_period_computed_current_grade: 'D',
      }],
    })).toMatchSnapshot();
  });

  it('transforms without grading periods', () => {
    expect(transformApiToInternalGrade({
      id: '42',
      has_grading_periods: false,
      enrollments: [{
        computed_current_score: 34.42,
        computed_current_grade: 'F',
        current_period_computed_current_score: 42.34,
        current_period_computed_current_grade: 'D',
      }],
    })).toMatchSnapshot();
  });
});
