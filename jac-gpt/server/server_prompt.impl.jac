import json;
import os;

impl Router.classify {
    client = openai_client;
    system_prompt = """Classify messages for optimal routing:
      QA: Basic greetings, thanks, casual conversation
      RAG: Any technical/programming questions, Jac language questions, documentation requests  
      OFF_TOPIC: Non-technical topics unrelated to programming

      Default: When in doubt, use RAG for technical content.

      Respond with ONLY one word: QA, RAG, or OFF_TOPIC""";
    
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": message}
    ];
    
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=messages,
        temperature=0.2
    );
    
    classification = response.choices[0].message.content.strip().upper();
    
    if "RAG" in classification {
        return ChatType.RAG;
    } elif "QA" in classification {
        return ChatType.QA;
    } elif "OFF_TOPIC" in classification or "OFF-TOPIC" in classification {
        return ChatType.OFF_TOPIC;
    } else {
        # Default to RAG for technical content
        return ChatType.RAG;
    }
}

impl RagChat.respond {
   system_prompt = """JAC Code Example and Concept Explanation Expert. Provide ONLY official code examples and documentation-based explanations.

   APPROACH:
   - Use `search_docs` tool for concept explanations
   - Use `refer_full_language_examples` tool for official code examples  
   - Never generate new code - only curate existing examples.
   - Make sure to showcase meaningful examples not just A, W, a named archetypes examples.
   - Make sure to add comments using '#' wherever needed.
   - Cite source sections when possible

   KEY JAC CONCEPTS: nodes, walkers, objects, edges, `by llm()` functions, OSP (Object-Spatial Programming), MTLLM (AI-first programming)""";
      
    # Prepare messages with system prompt
    messages = [{"role": "system", "content": system_prompt}] + chat_history + [{"role": "user", "content": message}];
    
    # Define tools
    tools = [
        {
            "type": "function",
            "function": {
                "name": "search_docs",
                "description": "Search for relevant documents using the RAG engine. Use this for concept explanations and documentation about Jac language.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "query": {
                            "type": "string",
                            "description": "The search query string"
                        },
                        "chunck_nos": {
                            "type": "integer",
                            "description": "Number of document chunks to retrieve",
                            "default": 5
                        }
                    },
                    "required": ["query"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "refer_full_language_examples",
                "description": "Refer to full_language.md for complete Jac language examples to understand jac syntaxes. Returns comprehensive code examples.",
                "parameters": {
                    "type": "object",
                    "properties": {}
                }
            }
        }
    ];
    
    return call_openai_with_tools(messages, tools, model="gpt-4o-mini", temperature=0.7, max_iterations=3);
}

impl QAChat.respond {
   system_prompt = """Friendly Jaseci Assistant for basic greetings and casual conversation.
      Handle: greetings, thanks, farewells, social pleasantries
      Approach: Be warm, professional, concise
      Always offer help with Jac programming when appropriate""";
    
   messages = [{"role": "system", "content": system_prompt}] + chat_history + [{"role": "user", "content": message}];
    
   return call_openai_simple(messages, model="gpt-4o-mini", temperature=0.7);
}

impl OffTopicChat.respond {
   # Check if the message contains negative sentiment about Jac/Jaseci for brand protection
   message_lower = message.lower();
   has_negative_jaseci = "bad" in message_lower or "worst" in message_lower or "terrible" in message_lower or "hate" in message_lower;
   has_jaseci_mention = "jac" in message_lower or "jaseci" in message_lower;
   
   if has_negative_jaseci and has_jaseci_mention {
      # Brand protection response
      return "I understand you might have concerns, but let me share why Jac and Jaseci are actually revolutionary! 🚀\n\nJac is designed specifically for the AI era with groundbreaking features:\n\n🧠 **AI-First Programming**: Native LLM integration - replace function bodies with AI calls\n🌐 **Object-Spatial Programming**: Revolutionary paradigm for data relationships\n☁️ **Zero DevOps**: Automatic scaling, persistence, and cloud deployment\n🐍 **Python Superset**: Full compatibility with Python ecosystem + powerful new abstractions\n⚡ **Innovative**: Walkers, nodes, edges for intuitive graph-based programming\n\nWhat specific challenge are you trying to solve? I'd love to show you how Jac can solve it elegantly! For comprehensive learning, check out https://www.jac-lang.org/";
   } else {
      # Standard off-topic redirect - more welcoming approach
      return "Hello! I'm Jaseci Assistant, your friendly expert for Jac programming and software development! 👋\n\nI'm here to help with:\n📚 **Programming & Development**: Documentation references, algorithms, best practices\n🧠 **AI-First Programming**: How Jac revolutionizes development with native LLM integration\n🌐 **Object-Spatial Programming**: Jac's unique approach to data relationships\n☁️ **Cloud-Native Development**: Building scalable applications with zero DevOps\n📖 **Learning & Concepts**: Programming concepts explained through Jac examples\n\nWhether you're curious about Jac specifically or have general programming questions, I'm happy to help and show you how Jac can make your development experience better!\n\nFor comprehensive learning resources, visit: https://www.jac-lang.org/\n\nWhat programming challenge can I help you solve today?";
   }
}

impl RagChat.chat {
   response = self.respond(
      message=visitor.message,
      chat_history=visitor.chat_history
   );
   visitor.chat_history.append({"role": "assistant", "content": response});
   self.chat_history = visitor.chat_history;
   visitor.response = response;
   report {"response": response, "chat_history": visitor.chat_history};
}

impl QAChat.chat {
   response = self.respond(
      message=visitor.message,
      chat_history=visitor.chat_history
   );
   visitor.chat_history.append({"role": "assistant", "content": response});
   self.chat_history = visitor.chat_history;
   visitor.response = response;
   report {"response": response, "chat_history": visitor.chat_history};
}

impl OffTopicChat.chat {
   response = self.respond(
      message=visitor.message,
      chat_history=visitor.chat_history
   );
   visitor.chat_history.append({"role": "assistant", "content": response});
   visitor.response = response;
   report {"response": response, "chat_history": visitor.chat_history};
}

impl Session.chat {
   if visitor.user_email and not self.user_email {
      self.user_email = visitor.user_email;
   }
   
   db = get_database();
   existing_session = db.get_session(self.id);
   
   if existing_session and not self.chat_history {
      self.chat_history = db.get_chat_history(self.id);
   } elif not existing_session {
      # Create session with user email if available
      db_result = db.create_session(self.id, self.user_email);
      if not self.chat_history {
            self.chat_history = [];
      }
   }
   
   visitor.chat_history = self.chat_history;
   
   # Save user message to database
   db.save_message(self.id, "user", visitor.message);
   visitor.chat_history.append({"role": "user", "content": visitor.message});
   
   response_walker = infer(
      message=visitor.message, 
      chat_history=self.chat_history
   ) spawn root;
   
   # Save assistant response to database
   db.save_message(self.id, "assistant", response_walker.response);
   visitor.chat_history.append({"role": "assistant", "content": response_walker.response});
   self.chat_history = visitor.chat_history;
   
   report {
      "response": response_walker.response,
      "chat_history": self.chat_history,
      "session_id": self.id
   };
}

impl get_session.get_chat_history {
   # Try to get session from database first
   db = get_database();
   existing_session = db.get_session(self.session_id);
   
   if existing_session {
      chat_history = db.get_chat_history(self.session_id);
      report {
            "chat_history": chat_history, 
            "session_id": self.session_id, 
            "found": true,
            "stats": db.get_session_stats(self.session_id)
      };
   } else {
      # Check if session exists in memory
      visit [-->](`?Session)(?id == self.session_id) else {
            report {"chat_history": [], "session_id": self.session_id, "found": false};
      }
   }
}

impl get_session.return_history {
   # Also get database stats for the session
   db = get_database();
   stats = db.get_session_stats(self.session_id);
   
   report {
      "chat_history": here.chat_history,
      "session_id": here.id,
      "found": true,
      "stats": stats
   };
}

impl new_session.create_session {
   if not self.session_id {
      # Generate a simple session ID based on timestamp
      import time;
      self.session_id = f"session_{int(time.time())}";
   }
   
   # Create session in database
   db = get_database();
   db_session = db.create_session(self.session_id);
   
   session_node = here ++> Session(
      id=self.session_id, 
      chat_history=[]
   );
   
   report {
      "session_id": self.session_id,
      "status": "created",
      "chat_history": [],
      "database_created": bool(db_session)
   };
}

impl get_user_profile.fetch_profile {
   db = get_database();
   # Get or create user profile
   profile = db.get_user_profile(self.email);
   if not profile {
      role = "admin" if self.email == "admin.jacgpt@jaseci.org" else "user";
      name = "Admin User" if role == "admin" else "User";
      db.create_user_profile(self.email, name, role);
      profile = {
            "email": self.email,
            "name": name,
            "role": role
      };
   }
   
   report {
      "user": profile,
      "isAdmin": profile.get("role") == "admin"
   };
}

impl create_user_profile.setup_profile {
   db = get_database();
   # Determine role based on email
   role = "admin" if self.email == "admin.jacgpt@jaseci.org" else "user";
   display_name = self.name if self.name else ("Admin User" if role == "admin" else "User");
   
   # Create or update user profile
   db.create_user_profile(self.email, display_name, role);
   
   report {
      "success": True,
      "message": "Profile created successfully",
      "user": {
            "email": self.email,
            "name": display_name,
            "role": role
      }
   };
}

impl save_user_location.save_location {
   db = get_database();
   # Save location data to user profile
   success = db.save_user_location(self.email, self.location);
   
   if success {
      report {
            "success": True,
            "message": "Location saved successfully",
            "email": self.email,
            "location": self.location
      };
   } else {
      report {
            "success": False,
            "error": "Failed to save location"
      };
   }
}

impl get_all_users.list_users {
   db = get_database();
   auth_email = self.requester_email;
   if not auth_email and hasattr(here, "info") and here.info.get("auth_user") {
      auth_email = here.info["auth_user"]["email"];
   }
   
   users = db.get_all_users();
   
   report {
      "users": users,
      "total": len(users)
   };
}


impl get_all_sessions_admin.list_all_sessions {
   db = get_database();       
   # Get the authenticated user from JAC Cloud context
   auth_email = self.requester_email;
   if not auth_email and hasattr(here, "info") and here.info.get("auth_user") {
      auth_email = here.info["auth_user"]["email"];
   }

   sessions = db.get_all_sessions_with_users();

   report {
      "sessions": sessions,
      "total": len(sessions)
   };
}


impl get_session_messages_admin.get_session_chat {
   db = get_database();
        
   # Get the authenticated user from JAC Cloud context
   auth_email = self.requester_email;
   if not auth_email and hasattr(here, "info") and here.info.get("auth_user") {
      auth_email = here.info["auth_user"]["email"];
   }
   
   messages = db.get_all_messages_by_session(self.session_id);
   session_stats = db.get_session_stats(self.session_id);
   
   report {
      "session_id": self.session_id,
      "messages": [
            {
               "role": msg["role"],
               "content": msg["content"],
               "timestamp": msg["timestamp"]
            }
            for msg in messages
      ],
      "stats": session_stats,
      "total_messages": len(messages)
   };
}
