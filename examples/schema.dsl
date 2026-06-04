schema Schema
state Draft
state Reviewing
state Released
entity Schema { title:text version:text }
effect notifyDependentSchemas
rule hasReview: preset allReferencesResolved
transition submitForReview: Draft -> Reviewing { rule hasAtLeastOneState rule hasAtLeastOneTransition }
transition approve: Reviewing -> Released { rule hasReview }
transition deprecate: Released -> Released { effect notifyDependentSchemas }
