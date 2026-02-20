from rest_framework import serializers

from .models import Conversation


class ConversationSerializer(serializers.ModelSerializer):
    participant_1_username = serializers.CharField(
        source="participant_1.username", read_only=True
    )
    participant_2_username = serializers.CharField(
        source="participant_2.username", read_only=True
    )

    class Meta:
        model = Conversation
        fields = [
            "id",
            "order",
            "participant_1",
            "participant_1_username",
            "participant_2",
            "participant_2_username",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def validate(self, attrs):
        p1 = attrs.get("participant_1")
        p2 = attrs.get("participant_2")
        if p1 and p2 and p1.id == p2.id:
            raise serializers.ValidationError(
                "Los dos participantes no pueden ser el mismo usuario."
            )
        return attrs


class MessageSerializer(serializers.Serializer):
    """Serializer de lectura para mensajes provenientes de MongoDB."""

    _id = serializers.CharField(read_only=True)
    conversation_id = serializers.CharField(read_only=True)
    sender_id = serializers.IntegerField(read_only=True)
    message = serializers.CharField(read_only=True)
    timestamp = serializers.DateTimeField(read_only=True)
