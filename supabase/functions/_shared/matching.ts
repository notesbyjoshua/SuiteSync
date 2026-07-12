type Student = {
  id: string; email: string; session: string; age: number; gender_identity: string; submitted_at: string;
  extroversion: number | null; organization: number | null; sound_level: number | null;
  bedtime_preference: string | null; preferred_suitemates: number | null;
  room_type: string | null; floor_preference: string | null; college_preference: string | null;
};
type Suite = {
  id: string; name: string; session: string | null; capacity: number; floor: number | null; college: string | null;
  single_rooms: number | null; double_rooms: number | null; members: Student[]; housingGroup: string | null; targetSize?: number;
};

const bedtimeMinutes: Record<string, number> = { '21:00': 0, '21:30': 30, '22:00': 60, '22:30': 90, '23:00': 120, '23:30': 150, '00:00_or_later': 180 };
const similarity = (a: number | null, b: number | null, range: number) => a == null || b == null ? 0.5 : 1 - Math.min(Math.abs(a - b) / range, 1);
const housingGroup = (student: Student) => student.gender_identity === 'male' ? 'male' : student.gender_identity === 'female' ? 'female' : 'gender_inclusive';

function pairScore(a: Student, b: Student) {
  return (
    similarity(a.extroversion, b.extroversion, 4) * 0.2 +
    similarity(a.organization, b.organization, 4) * 0.25 +
    similarity(a.sound_level, b.sound_level, 4) * 0.25 +
    similarity(bedtimeMinutes[a.bedtime_preference || ''] ?? null, bedtimeMinutes[b.bedtime_preference || ''] ?? null, 180) * 0.2 +
    similarity(a.age, b.age, 3) * 0.1
  );
}

function locationScore(student: Student, suite: Suite) {
  const college = student.college_preference === 'no_preference' || !student.college_preference ? 1 : student.college_preference === suite.college ? 1 : 0;
  const floor = student.floor_preference === 'no_preference' || !student.floor_preference ? 1 : student.floor_preference === 'higher' ? ((suite.floor ?? 1) >= 3 ? 1 : 0) : ((suite.floor ?? 4) <= 2 ? 1 : 0);
  return (college + floor) / 2;
}

function roomScore(student: Student, suite: Suite) {
  if (!student.room_type || student.room_type === 'no_preference') return 1;
  if (student.room_type === 'single') return (suite.single_rooms ?? 0) > 0 ? 1 : 0;
  return (suite.double_rooms ?? 0) > 0 ? 1 : 0;
}

function placementScore(student: Student, suite: Suite, excludingId?: string) {
  const peers = suite.members.filter(member => member.id !== excludingId);
  const compatibility = peers.length ? peers.reduce((sum, peer) => sum + pairScore(student, peer), 0) / peers.length : 0.7;
  const futureSuitemates = peers.length;
  const size = student.preferred_suitemates == null ? 0.7 : 1 - Math.min(Math.abs(student.preferred_suitemates - futureSuitemates) / 8, 1);
  return compatibility * 0.55 + locationScore(student, suite) * 0.15 + roomScore(student, suite) * 0.15 + size * 0.15;
}

function eligible(student: Student, suite: Suite) {
  const group = housingGroup(student);
  return (!suite.session || suite.session === student.session) && suite.members.length < (suite.targetSize ?? suite.capacity) && (!suite.housingGroup || suite.housingGroup === group);
}

function optionCount(student: Student, suites: Suite[]) {
  return suites.filter(suite => eligible(student, suite) && locationScore(student, suite) > 0 && roomScore(student, suite) > 0).length;
}

export async function executeMatching(client: any, actorId: string, triggerType: 'manual' | 'scheduled' = 'manual') {
  const { data: run, error: runError } = await client.from('matching_runs').insert({ status: 'running', trigger_type: triggerType, started_at: new Date().toISOString(), created_by: actorId }).select('id').single();
  if (runError) throw runError;
  try {
    const [studentResult, suiteResult] = await Promise.all([
      client.from('survey_responses').select('id,email,session,age,gender_identity,extroversion,organization,sound_level,bedtime_preference,preferred_suitemates,room_type,floor_preference,college_preference,submitted_at').neq('matching_status', 'excluded'),
      client.from('suites').select('id,name,session,capacity,floor,college,single_rooms,double_rooms').order('created_at'),
    ]);
    if (studentResult.error || suiteResult.error) throw studentResult.error || suiteResult.error;
    const students = (studentResult.data ?? []) as Student[];
    const suites = (suiteResult.data ?? []).map((suite: any) => ({ ...suite, members: [], housingGroup: null })) as Suite[];
    if (!students.length) throw new Error('No eligible survey responses are available');
    if (suites.reduce((sum, suite) => sum + suite.capacity, 0) < students.length) throw new Error('Not enough suite capacity for all eligible applicants');

    const grouped = new Map<string, Student[]>();
    const reserved = new Set<string>();
    const protectedIds = new Set<string>();

    // Keep the named demo roommates together in the suite shown on the My Suite page.
    const franklin201 = suites.find(suite => suite.name === 'Franklin 201');
    const protectedEmails = ['joshuabie2010@gmail.com', 'alex@example.com', 'samira@example.com', 'mateo@example.com'];
    const protectedStudents = students.filter(student => protectedEmails.includes(student.email.toLowerCase()));
    if (protectedStudents.length) {
      if (!franklin201) throw new Error('Franklin 201 is required for the demo suitemates');
      if (protectedStudents.length !== protectedEmails.length) throw new Error('Joshua, Alex, Samuel, and Mateo must all have eligible survey responses');
      if (protectedStudents.some(student => student.session !== protectedStudents[0].session)) throw new Error('The Franklin 201 demo suitemates must be in the same session');
      if (protectedStudents.length > franklin201.capacity || (franklin201.double_rooms ?? 0) * 2 < protectedStudents.length) throw new Error('Franklin 201 does not have enough double rooms for the demo suitemates');
      reserved.add(franklin201.id);
      franklin201.housingGroup = 'male';
      franklin201.targetSize = protectedStudents.length;
      franklin201.members.push(...protectedStudents);
      protectedStudents.forEach(student => protectedIds.add(student.id));
    }

    // A request for zero suitemates is explicit: reserve a one-person suite with a single room.
    const soloStudents = students
      .filter(student => student.preferred_suitemates === 0 && !protectedIds.has(student.id))
      .sort((a, b) => a.submitted_at.localeCompare(b.submitted_at) || a.id.localeCompare(b.id));
    for (const student of soloStudents) {
      const candidates = suites.filter(suite =>
        !reserved.has(suite.id) &&
        (!suite.session || suite.session === student.session) &&
        (suite.single_rooms ?? 0) >= 1
      );
      candidates.sort((a, b) =>
        Number(b.capacity === 1) - Number(a.capacity === 1) ||
        locationScore(student, b) - locationScore(student, a) ||
        a.capacity - b.capacity ||
        a.id.localeCompare(b.id)
      );
      const suite = candidates[0];
      if (!suite) throw new Error(`No single-person suite is available for ${student.session} applicant requesting zero suitemates`);
      reserved.add(suite.id);
      suite.housingGroup = housingGroup(student);
      suite.targetSize = 1;
      suite.members.push(student);
    }

    for (const student of students.filter(student => student.preferred_suitemates !== 0 && !protectedIds.has(student.id))) {
      const key = `${student.session}::${housingGroup(student)}`;
      grouped.set(key, [...(grouped.get(key) ?? []), student]);
    }
    const groups = [...grouped.entries()].sort(([, a], [, b]) => b.length - a.length);
    for (const [, groupStudents] of groups) {
      const sample = groupStudents[0];
      const minimumSuites = Math.ceil(groupStudents.length / 9);
      const maximumSuites = groupStudents.length;
      const candidates = suites.filter(suite => !reserved.has(suite.id) && (!suite.session || suite.session === sample.session));
      candidates.sort((a, b) => {
        const preferenceA = groupStudents.reduce((sum, student) => sum + locationScore(student, a) + roomScore(student, a), 0);
        const preferenceB = groupStudents.reduce((sum, student) => sum + locationScore(student, b) + roomScore(student, b), 0);
        return preferenceB - preferenceA || b.capacity - a.capacity || a.id.localeCompare(b.id);
      });
      let selected: Suite[] | null = null;
      for (let count = minimumSuites; count <= maximumSuites; count++) {
        const attempt = candidates.slice(0, count);
        if (attempt.length === count && attempt.reduce((sum, suite) => sum + suite.capacity, 0) >= groupStudents.length) { selected = attempt; break; }
      }
      if (!selected) throw new Error(`Not enough compatible suite inventory for ${sample.session} ${housingGroup(sample)}`);
      selected.forEach(suite => { reserved.add(suite.id); suite.housingGroup = housingGroup(sample); suite.targetSize = 1; });
      let remaining = groupStudents.length - selected.length;
      while (remaining > 0) {
        let distributed = false;
        for (const suite of selected) {
          if (remaining === 0) break;
          if ((suite.targetSize ?? 1) < suite.capacity && (suite.targetSize ?? 1) < 9) {
            suite.targetSize = (suite.targetSize ?? 1) + 1;
            remaining--;
            distributed = true;
          }
        }
        if (!distributed) break;
      }
      if (remaining) throw new Error(`Suite capacities cannot fit ${sample.session} ${housingGroup(sample)} applicants`);

      const ordered = [...groupStudents].sort((a, b) => optionCount(a, selected!) - optionCount(b, selected!) || a.id.localeCompare(b.id));
      for (const student of ordered) {
        const available = selected.filter(suite => eligible(student, suite));
        available.sort((a, b) => placementScore(student, b) - placementScore(student, a) || a.id.localeCompare(b.id));
        if (!available.length) throw new Error(`No eligible suite remains for a ${student.session} ${housingGroup(student)} applicant`);
        available[0].members.push(student);
      }
    }

    let improved = true;
    let passes = 0;
    while (improved && passes++ < 50) {
      improved = false;
      outer: for (let i = 0; i < suites.length; i++) for (let j = i + 1; j < suites.length; j++) {
        const left = suites[i], right = suites[j];
        if (left.housingGroup !== right.housingGroup || (left.session && right.session && left.session !== right.session)) continue;
        for (const a of [...left.members]) for (const b of [...right.members]) {
          if (a.session !== b.session || housingGroup(a) !== housingGroup(b) || protectedIds.has(a.id) || protectedIds.has(b.id) || a.preferred_suitemates === 0 || b.preferred_suitemates === 0 || left.targetSize === 1 || right.targetSize === 1) continue;
          const beforeA = placementScore(a, left, a.id), beforeB = placementScore(b, right, b.id);
          const afterA = placementScore(a, right, b.id), afterB = placementScore(b, left, a.id);
          const totalGain = afterA + afterB - beforeA - beforeB;
          const protectsWorst = Math.min(afterA, afterB) > Math.min(beforeA, beforeB) + 0.05 && totalGain > -0.02;
          if (totalGain > 0.001 || protectsWorst) {
            left.members = left.members.filter(member => member.id !== a.id); right.members = right.members.filter(member => member.id !== b.id);
            left.members.push(b); right.members.push(a); improved = true; break outer;
          }
        }
      }
    }

    const assignments = suites.flatMap(suite => {
      const minimumSingles = Math.max(0, suite.members.length - (suite.double_rooms ?? 0) * 2);
      const availableSingles = Math.min(suite.single_rooms ?? 0, suite.members.length);
      const singleCount = Math.max(minimumSingles, Math.min(availableSingles, suite.members.filter(student => student.room_type === 'single' && !protectedIds.has(student.id)).length));
      const roomOrder = [...suite.members].sort((a, b) => {
        const rank = (student: Student) => protectedIds.has(student.id) ? 3 : student.room_type === 'single' ? 0 : student.room_type === 'no_preference' ? 1 : 2;
        return rank(a) - rank(b) || a.submitted_at.localeCompare(b.submitted_at) || a.id.localeCompare(b.id);
      });
      const singleIds = new Set(roomOrder.slice(0, singleCount).map(student => student.id));
      return suite.members.map(student => ({ response_id: student.id, suite_id: suite.id, score: Number(placementScore(student, suite, student.id).toFixed(4)), housing_group: suite.housingGroup, assigned_room_type: singleIds.has(student.id) ? 'single' : 'double' }));
    });
    const scores = assignments.map(item => item.score);
    const summary = { applicants: students.length, suites_used: suites.filter(s => s.members.length).length, local_search_passes: passes, average_score: scores.reduce((a, b) => a + b, 0) / scores.length, minimum_score: Math.min(...scores) };
    const { error: applyError } = await client.rpc('apply_matching_assignments', { assignment_data: assignments, matching_run_id: run.id, actor_user_id: actorId });
    if (applyError) throw applyError;
    await client.from('matching_runs').update({ status: 'completed', completed_at: new Date().toISOString(), summary }).eq('id', run.id);
    return { runId: run.id, summary };
  } catch (error) {
    const message = error instanceof Error ? error.message : typeof error === 'object' && error && 'message' in error ? String(error.message) : JSON.stringify(error);
    await client.from('matching_runs').update({ status: 'failed', completed_at: new Date().toISOString(), notes: message }).eq('id', run.id);
    throw new Error(message || 'Matching failed');
  }
}
