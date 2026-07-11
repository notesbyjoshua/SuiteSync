def compatibility(a, b):

    # Hard constraints

    if a.sex != b.sex:
        return -1

    if a.snore or b.snore:
        return -1

    score = 0

    # Sleep (25 pts)

    sleep_difference = abs(a.sleep - b.sleep)

    score += max(0, 25 - sleep_difference * 5)

    # Wake (10 pts)

    wake_difference = abs(a.wake - b.wake)

    score += max(0, 10 - wake_difference * 2)

    # Noise (20 pts)

    score += max(0, 20 - abs(a.noise - b.noise) * 10)

    # Hobbies (20 pts)

    intersection = len(a.hobbies & b.hobbies)

    union = len(a.hobbies | b.hobbies)

    if union != 0:
        score += 20 * intersection / union

    # Track preference

    if a.same_track:

        if a.track == b.track:
            score += 10

    else:

        score += 10

    return score
