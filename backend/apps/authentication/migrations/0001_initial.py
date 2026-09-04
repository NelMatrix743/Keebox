import uuid
from typing import ClassVar

import django.utils.timezone
from django.db import migrations, models
from django.db.migrations.operations.base import Operation

import apps.authentication.models



class Migration(migrations.Migration):

    initial: bool = True

    dependencies: ClassVar[list[tuple[str, str]]] = [
        ('auth', '0012_alter_user_first_name_max_length'),
    ]

    operations: ClassVar[list[Operation]] = [
        migrations.CreateModel(
            name='User',
            fields=[
                ('password', models.CharField(max_length=128, verbose_name='password')),
                ('last_login', models.DateTimeField(blank=True, null=True, verbose_name='last login')),
                ('is_superuser', models.BooleanField(default=False, help_text='Designates that this user has all permissions without explicitly assigning them.', verbose_name='superuser status')),
                ('is_staff', models.BooleanField(default=False, help_text='Designates whether the user can log into this admin site.', verbose_name='staff status')),
                ('is_active', models.BooleanField(default=True, help_text='Designates whether this user should be treated as active. Unselect this instead of deleting accounts.', verbose_name='active')),
                ('date_joined', models.DateTimeField(default=django.utils.timezone.now, verbose_name='date joined')),
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('email', models.EmailField(max_length=254, unique=True)),
                ('first_name', models.CharField(max_length=150)),
                ('last_name', models.CharField(max_length=150)),
                ('pin_hash', models.CharField(blank=True, max_length=255, null=True)),
                ('pin_version', models.PositiveIntegerField(default=0)),
                ('encrypted_kbkey', models.BinaryField(blank=True, null=True)),
                ('kbkey_nonce', models.BinaryField(blank=True, max_length=12, null=True)),
                ('kbkey_encryption_version', models.PositiveSmallIntegerField(default=1)),
                ('groups', models.ManyToManyField(blank=True, help_text='The groups this user belongs to. A user will get all permissions granted to each of their groups.', related_name='user_set', related_query_name='user', to='auth.group', verbose_name='groups')),
                ('user_permissions', models.ManyToManyField(blank=True, help_text='Specific permissions for this user.', related_name='user_set', related_query_name='user', to='auth.permission', verbose_name='user permissions')),
            ],
            options={
                'verbose_name': 'user',
                'verbose_name_plural': 'users',
                'abstract': False,
            },
            managers=[
                ('objects', apps.authentication.models.UserManager()),
            ],
        ),
        migrations.CreateModel(
            name='RegistrationChallenge',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('first_name', models.CharField(max_length=150)),
                ('last_name', models.CharField(max_length=150)),
                ('email', models.EmailField(max_length=254, unique=True)),
                ('password_hash', models.CharField(max_length=128)),
                ('status', models.CharField(choices=[('otp_pending', 'OTP pending'), ('otp_verified', 'OTP verified'), ('completed', 'Completed'), ('expired', 'Expired'), ('cancelled', 'Cancelled')], default='otp_pending', max_length=20)),
                ('expires_at', models.DateTimeField(default=apps.authentication.models.registration_challenge_expiration)),
                ('completed_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
        ),
    ]
