class ReportesReplicaRouter:
    def db_for_read(self, model, **hints):
        if model._meta.app_label in ('usuario', 'empresa', 'sessions', 'social_django', 'auth'):
            return 'accounts'
        return 'default'

    def db_for_write(self, model, **hints):
        if model._meta.app_label in ('usuario', 'empresa', 'sessions', 'social_django', 'auth'):
            return 'accounts'
        return 'default'

    def allow_relation(self, obj1, obj2, **hints):
        return True

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        if app_label in ('usuario', 'empresa', 'sessions', 'social_django', 'auth'):
            return db == 'accounts'
        return db == 'default'